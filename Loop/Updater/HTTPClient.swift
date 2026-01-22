//
//  HTTPClient.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import CryptoKit
import Foundation
import Scribe

@Loggable(style: .static)
public actor HTTPClient {
    public struct SecurityConfig: Sendable {
        let maxRequestLifetime: TimeInterval
        let allowedHosts: Set<String>
        let certificatePinning: [String: Data]
        let maxResponseSize: Int
        let enableRequestSigning: Bool

        public static let `default`: SecurityConfig = .init(
            maxRequestLifetime: 30.0,
            allowedHosts: [],
            certificatePinning: [:],
            maxResponseSize: 104_857_600,
            enableRequestSigning: true
        )
    }

    private struct RequestContext: Sendable {
        let id: UUID
        let startTime: Date
        let url: URL
        let method: HTTPMethod
        let maxLifetime: TimeInterval

        var isExpired: Bool {
            Date().timeIntervalSince(startTime) > maxLifetime
        }

        var remainingTime: TimeInterval {
            max(0, maxLifetime - Date().timeIntervalSince(startTime))
        }
    }

    private enum HTTPMethod: Sendable {
        case GET, DELETE
        case POST(any Codable & Sendable)
        case PUT(any Codable & Sendable)

        var name: String {
            switch self {
            case .GET: "GET"
            case .POST: "POST"
            case .PUT: "PUT"
            case .DELETE: "DELETE"
            }
        }

        var hasBody: Bool {
            switch self {
            case .GET,
                 .DELETE: false
            case .POST,
                 .PUT: true
            }
        }
    }

    private let config: UpdaterConfig
    private let securityConfig: SecurityConfig
    private let session: URLSession
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    private let requestSigningKey: SymmetricKey
    private var activeRequests: [UUID: RequestContext] = [:]

    public init(config: UpdaterConfig, securityConfig: SecurityConfig = .default) {
        self.config = config
        self.securityConfig = securityConfig
        self.requestSigningKey = SymmetricKey(size: .bits256)

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.networkConfig.timeout
        sessionConfig.timeoutIntervalForResource = min(
            config.networkConfig.timeout * 3,
            securityConfig.maxRequestLifetime
        )
        sessionConfig.allowsCellularAccess = config.networkConfig.allowsCellularAccess
        sessionConfig.waitsForConnectivity = true
        sessionConfig.networkServiceType = .default
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfig.httpMaximumConnectionsPerHost = 10
        sessionConfig.httpAdditionalHeaders = [
            "User-Agent": "Loop/1.0 (\(SystemInfo.deviceModel); \(SystemInfo.osVersion))",
            "Accept": "application/json",
            "Accept-Encoding": "gzip, deflate, br",
            "Accept-Language": Locale.current.languageCode ?? "en",
            "Cache-Control": "no-cache",
            "X-Request-ID": UUID().uuidString,
            "X-Client-Version": "1.0",
            "DNT": "1"
        ]

        self.session = URLSession(
            configuration: sessionConfig,
            delegate: SecurityDelegate(securityConfig: securityConfig),
            delegateQueue: nil
        )

        self.jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.outputFormatting = .sortedKeys

        self.jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601

        Task { await startRequestCleanupTask() }
    }

    deinit {
        session.invalidateAndCancel()
    }

    public func fetchData(from url: URL) async throws -> Data {
        try await performRequest(url: url, method: .GET)
    }

    public func post<ResponseBody: Codable & Sendable>(
        to url: URL,
        body: some Codable & Sendable,
        expecting responseType: ResponseBody.Type
    ) async throws -> ResponseBody {
        let data = try await performRequest(url: url, method: .POST(body))
        return try jsonDecoder.decode(responseType, from: data)
    }

    public func put<ResponseBody: Codable & Sendable>(
        to url: URL,
        body: some Codable & Sendable,
        expecting responseType: ResponseBody.Type
    ) async throws -> ResponseBody {
        let data = try await performRequest(url: url, method: .PUT(body))
        return try jsonDecoder.decode(responseType, from: data)
    }

    public func delete(from url: URL) async throws {
        _ = try await performRequest(url: url, method: .DELETE)
    }

    private func performRequest(url: URL, method: HTTPMethod) async throws -> Data {
        try validateRequestSecurity(url: url)

        let context = RequestContext(
            id: UUID(),
            startTime: Date(),
            url: url,
            method: method,
            maxLifetime: securityConfig.maxRequestLifetime
        )

        activeRequests[context.id] = context
        defer { activeRequests.removeValue(forKey: context.id) }

        Log.debug("Starting \(method.name) request to: \(url) [ID: \(context.id)]")

        return try await withTimeout(context.remainingTime) {
            try await self.performRequestWithRetry(context: context)
        }
    }

    private func validateRequestSecurity(url: URL) throws {
        if !securityConfig.allowedHosts.isEmpty,
           let host = url.host,
           !securityConfig.allowedHosts.contains(host) {
            Log.error("Request to unauthorized host: \(host)")
            throw UpdateError.securityViolation("Unauthorized host")
        }

        guard url.scheme == "https" || url.host == "localhost" else {
            Log.error("Insecure connection attempted: \(url.scheme ?? "unknown")")
            throw UpdateError.securityViolation("HTTPS required")
        }
    }

    private func withTimeout<T: Sendable>(
        _ timeout: TimeInterval,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw UpdateError.timeout
            }

            guard let result = try await group.next() else {
                throw UpdateError.timeout
            }

            group.cancelAll()
            return result
        }
    }

    private func performRequestWithRetry(context: RequestContext) async throws -> Data {
        var lastError: Error?
        let maxRetries = config.networkConfig.retryCount

        for attempt in 1...maxRetries {
            guard !context.isExpired else {
                Log.error("Request expired [ID: \(context.id)]")
                throw UpdateError.timeout
            }

            do {
                let request = try createRequest(context: context)
                let (data, response) = try await session.data(for: request)
                let validatedData = try validateAndProcessResponse(response, data: data, context: context)

                Log.debug("Request completed successfully [ID: \(context.id), Size: \(validatedData.count) bytes]")
                return validatedData

            } catch let error as UpdateError where !error.isRetryable {
                Log.error("Non-retryable error [ID: \(context.id)]: \(error)")
                throw error
            } catch {
                lastError = error
                Log.warn("Attempt \(attempt)/\(maxRetries) failed [ID: \(context.id)]: \(error)")

                if attempt < maxRetries, !context.isExpired {
                    let delay = calculateBackoffDelay(attempt: attempt)
                    Log.info("Retrying in \(String(format: "%.1f", delay))s [ID: \(context.id)]")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? UpdateError.networkError(URLError(.unknown))
    }

    private func createRequest(context: RequestContext) throws -> URLRequest {
        var request = URLRequest(url: context.url)
        request.httpMethod = context.method.name
        request.setValue(context.id.uuidString, forHTTPHeaderField: "X-Request-ID")

        if securityConfig.enableRequestSigning {
            let signature = createRequestSignature(context: context)
            request.setValue(signature, forHTTPHeaderField: "X-Request-Signature")
        }

        if context.method.hasBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encodeRequestBody(method: context.method)
        }

        return request
    }

    private func encodeRequestBody(method: HTTPMethod) throws -> Data {
        switch method {
        case let .POST(body),
             let .PUT(body):
            try jsonEncoder.encode(body)
        default:
            Data()
        }
    }

    private func createRequestSignature(context: RequestContext) -> String {
        let data = "\(context.method.name)|\(context.url.absoluteString)|\(context.startTime.timeIntervalSince1970)"
            .data(using: .utf8) ?? Data()
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: requestSigningKey)
        return Data(signature).base64EncodedString()
    }

    private func validateAndProcessResponse(
        _ response: URLResponse,
        data: Data,
        context: RequestContext
    ) throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse else {
            Log.error("Invalid response type [ID: \(context.id)]")
            throw UpdateError.networkError(URLError(.badServerResponse))
        }

        guard data.count <= securityConfig.maxResponseSize else {
            Log.error("Response too large: \(data.count) bytes [ID: \(context.id)]")
            throw UpdateError.securityViolation("Response size exceeded")
        }

        try validateHTTPStatus(httpResponse, context: context)

        if case .GET = context.method {
            try validateJSONResponse(data: data, context: context)
        }

        logResponseMetrics(httpResponse, data: data, context: context)
        return data
    }

    private func validateHTTPStatus(_ response: HTTPURLResponse, context: RequestContext) throws {
        Log.debug("HTTP \(response.statusCode) [ID: \(context.id)]")

        switch response.statusCode {
        case 200...299:
            return
        case 400...499:
            Log.error("Client error \(response.statusCode) [ID: \(context.id)]")
            throw UpdateError.clientError(response.statusCode)
        case 500...599:
            Log.error("Server error \(response.statusCode) [ID: \(context.id)]")
            throw UpdateError.serverError(response.statusCode)
        default:
            Log.error("Unexpected status \(response.statusCode) [ID: \(context.id)]")
            throw UpdateError.networkError(URLError(.badServerResponse))
        }
    }

    private func validateJSONResponse(data: Data, context: RequestContext) throws {
        guard !data.isEmpty else {
            Log.warn("Empty response [ID: \(context.id)]")
            return
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            Log.error("Invalid JSON [ID: \(context.id)]: \(error)")
            throw UpdateError.invalidManifest
        }
    }

    private func logResponseMetrics(_ response: HTTPURLResponse, data: Data, context: RequestContext) {
        let duration = Date().timeIntervalSince(context.startTime)
        let headers = ["Content-Type", "Content-Length", "Cache-Control"]
            .compactMap { key in
                response.value(forHTTPHeaderField: key).map { "\(key): \($0)" }
            }
            .joined(separator: ", ")

        Log
            .debug(
                "Response metrics [ID: \(context.id)]: \(String(format: "%.3f", duration))s, \(data.count) bytes, \(headers)"
            )
    }

    private func calculateBackoffDelay(attempt: Int) -> Double {
        let baseDelay = config.networkConfig.retryDelay
        let exponentialBackoff = baseDelay * pow(2.0, Double(attempt - 1))
        let jitter = Double.random(in: 0.8...1.2)
        return min(exponentialBackoff * jitter, 30.0)
    }

    private func startRequestCleanupTask() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            await cleanupExpiredRequests()
        }
    }

    private func cleanupExpiredRequests() {
        let expiredIds = activeRequests.compactMap { id, context in
            context.isExpired ? id : nil
        }

        for id in expiredIds {
            activeRequests.removeValue(forKey: id)
            Log.warn("Cleaned up expired request [ID: \(id)]")
        }
    }
}

// MARK: - SecurityDelegate

private final class SecurityDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let securityConfig: HTTPClient.SecurityConfig

    init(securityConfig: HTTPClient.SecurityConfig) {
        self.securityConfig = securityConfig
        super.init()
    }

    func urlSession(
        _: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> ()
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if let serverTrust = challenge.protectionSpace.serverTrust,
           let pinnedCert = securityConfig.certificatePinning[challenge.protectionSpace.host] {
            if validateCertificatePinning(serverTrust: serverTrust, pinnedCertificate: pinnedCert) {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
            } else {
                Log.error("Certificate pinning validation failed for host: \(challenge.protectionSpace.host)")
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    private func validateCertificatePinning(serverTrust: SecTrust, pinnedCertificate: Data) -> Bool {
        guard let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            return false
        }

        let serverCertData = SecCertificateCopyData(serverCertificate)
        let serverCertBytes = CFDataGetBytePtr(serverCertData)
        let serverCertLength = CFDataGetLength(serverCertData)

        guard let serverBytes = serverCertBytes else { return false }

        let serverData = Data(bytes: serverBytes, count: serverCertLength)
        return serverData == pinnedCertificate
    }
}
