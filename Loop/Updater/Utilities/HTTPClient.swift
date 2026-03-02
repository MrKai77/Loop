//
//  HTTPClient.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import Foundation
import Scribe

@Loggable(style: .static)
final class HTTPClient: Sendable {
    private let session: URLSession
    private let jsonDecoder: JSONDecoder

    init() {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30.0
        sessionConfig.httpAdditionalHeaders = [
            "User-Agent": "Loop/\(Bundle.main.appVersion ?? "1.0.0") (\(SystemInfo.deviceModel); \(ProcessInfo.processInfo.operatingSystemVersion))",
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

    func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateError.network(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw UpdateError.http(httpResponse.statusCode)
        }

        return data
    }
}
