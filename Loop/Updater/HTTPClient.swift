//
//  HTTPClient.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import Foundation
import Scribe

@Loggable(style: .static)
public final class HTTPClient: Sendable {
    private let config: UpdaterConfig
    private let session: URLSession
    private let jsonDecoder: JSONDecoder

    public init(config: UpdaterConfig) {
        self.config = config

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.networkConfig.timeout
        sessionConfig.allowsCellularAccess = config.networkConfig.allowsCellularAccess
        sessionConfig.httpAdditionalHeaders = [
            "User-Agent": "Loop/1.4.1 (\(SystemInfo.deviceModel); \(SystemInfo.osVersion))",
            "Accept": "application/json",
            "Accept-Encoding": "gzip, deflate"
        ]

        self.session = URLSession(configuration: sessionConfig)
        self.jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
    }

    deinit {
        session.invalidateAndCancel()
    }

    public func fetchJSON<T: Decodable>(from url: URL) async throws -> T {
        let data = try await fetchData(from: url)
        return try jsonDecoder.decode(T.self, from: data)
    }

    public func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateError.network(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw UpdateError.httpError(httpResponse)
        }

        return data
    }
}
