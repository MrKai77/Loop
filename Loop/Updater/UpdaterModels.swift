//
//  UpdaterModels.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import Foundation

// MARK: - UpdateChannel

enum UpdateChannel: String, Sendable, CaseIterable {
    case stable
    case beta

    var displayName: String {
        switch self {
        case .stable: "Stable"
        case .beta: "Beta"
        }
    }

    var isDevelopmentChannel: Bool {
        switch self {
        case .stable: false
        case .beta: true
        }
    }

    var githubReleasesEndpoint: String {
        switch self {
        case .stable: "https://api.github.com/repos/MrKai77/Loop/releases/latest"
        case .beta: "https://api.github.com/repos/MrKai77/Loop/releases"
        }
    }
}

// MARK: - UpdateManifest

struct UpdateManifest: Sendable {
    let version: String
    let buildNumber: Int
    let downloadUrl: String
    let releaseNotes: ReleaseNotes
    let checksums: Checksums
    let minimumOS: String
    let channel: UpdateChannel
    let publishedAt: Date
    let size: Int64

    struct ReleaseNotes: Sendable {
        let title: String
        let body: String
        let compatibility: Compatibility

        struct Compatibility: Sendable {
            let downloadSize: Int64
            let minimumOS: String
            let maximumOS: String?
            let supportedArchitectures: [String]
        }
    }

    struct Checksums: Sendable {
        let zip: String
    }

    // Create UpdateManifest from GitHub Release
    static func from(release: Release) -> UpdateManifest? {
        guard let asset = release.assets.first(where: { $0.name.hasSuffix(".zip") }) else {
            return nil
        }

        // Extract checksum from asset digest (format: "sha256:checksum")
        let zipChecksum = asset.digest?.replacingOccurrences(of: "sha256:", with: "") ?? ""

        return UpdateManifest(
            version: release.tagName,
            buildNumber: release.buildNumber ?? 0,
            downloadUrl: asset.browserDownloadURL.absoluteString,
            releaseNotes: ReleaseNotes(
                title: release.name,
                body: release.body,
                compatibility: ReleaseNotes.Compatibility(
                    downloadSize: Int64(asset.size),
                    minimumOS: "13.0",
                    maximumOS: nil,
                    supportedArchitectures: ["arm64", "x86_64"]
                )
            ),
            checksums: Checksums(
                zip: zipChecksum
            ),
            minimumOS: "13.0",
            channel: release.prerelease ? .beta : .stable,
            publishedAt: release.publishedAt,
            size: Int64(asset.size)
        )
    }
}

// MARK: - UpdateProgress

struct UpdateProgress: Sendable {
    let phase: UpdatePhase
    let percentage: Double
    let bytesDownloaded: Int64
    let totalBytes: Int64
    let estimatedTimeRemaining: TimeInterval?
    let downloadSpeed: Double?

    enum UpdatePhase: String, Sendable {
        case checking, downloading, extracting, verifying, installing, completed, failed
    }

    init(
        phase: UpdatePhase,
        percentage: Double,
        bytesDownloaded: Int64 = 0,
        totalBytes: Int64 = 0,
        estimatedTimeRemaining: TimeInterval? = nil,
        downloadSpeed: Double? = nil
    ) {
        self.phase = phase
        self.percentage = percentage
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.downloadSpeed = downloadSpeed
    }
}

// MARK: - UpdateError

enum UpdateError: LocalizedError, Sendable {
    case network(Error)
    case invalidManifest(String? = nil)
    case checksumMismatch
    case installationFailed(String)
    case security(String)
    case timeout
    case http(Int)

    var errorDescription: String? {
        switch self {
        case let .network(error):
            "Network error: \(error.localizedDescription)"
        case let .invalidManifest(details):
            details.map { "Invalid update manifest: \($0)" } ?? "Invalid update manifest"
        case .checksumMismatch:
            "File integrity check failed"
        case let .installationFailed(reason):
            "Installation failed: \(reason)"
        case let .security(reason):
            "Security error: \(reason)"
        case .timeout:
            "Request timed out"
        case let .http(code):
            "HTTP error (\(code))"
        }
    }

    var isRetryable: Bool {
        switch self {
        case let .network(error):
            if let urlError = error as? URLError {
                return [.timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed].contains(urlError.code)
            }
            return false
        case .timeout:
            return true
        case let .http(code) where code >= 500:
            return true
        default:
            return false
        }
    }

    // Convenience constructors
    static func httpError(_ response: HTTPURLResponse) -> UpdateError {
        .http(response.statusCode)
    }

    static func installationError(_ message: String) -> UpdateError {
        .installationFailed(message)
    }

    static func securityError(_ reason: String) -> UpdateError {
        .security(reason)
    }

    static func manifestError(_ details: String? = nil) -> UpdateError {
        .invalidManifest(details)
    }
}

// MARK: - UpdaterConfig

struct UpdaterConfig: Sendable {
    let updateEndpoint: URL
    let currentBuildNumber: Int
    let userGroup: String?
    let networkConfig: NetworkConfig

    struct SecurityConfig: Sendable {
        let checksumValidationEnabled: Bool
        let codeSignatureValidationEnabled: Bool

        static let `default`: SecurityConfig = .init(
            checksumValidationEnabled: true,
            codeSignatureValidationEnabled: false
        )
    }

    struct NetworkConfig: Sendable {
        let timeout: TimeInterval
        let retryCount: Int
        let retryDelay: TimeInterval
        let allowsCellularAccess: Bool

        static let `default`: NetworkConfig = .init(
            timeout: 30.0,
            retryCount: 3,
            retryDelay: 2.0,
            allowsCellularAccess: true
        )
    }

    init(
        updateEndpoint: URL,
        currentBuildNumber: Int,
        userGroup: String? = nil,
        networkConfig: NetworkConfig = .default
    ) {
        self.updateEndpoint = updateEndpoint
        self.currentBuildNumber = currentBuildNumber
        self.userGroup = userGroup
        self.networkConfig = networkConfig
    }
}

// MARK: - Release Model

// Release model to parse GitHub API response for releases.
struct Release: Codable {
    var id: Int
    var tagName: String
    var name: String
    var body: String
    var assets: [Asset]
    var prerelease: Bool
    var createdAt: Date
    var updatedAt: Date
    var publishedAt: Date

    var buildNumber: Int?

    enum CodingKeys: String, CodingKey {
        case id, tagName = "tag_name", name, body, assets, prerelease, createdAt = "created_at", updatedAt = "updated_at", publishedAt = "published_at"
    }

    struct Asset: Codable {
        var name: String
        var browserDownloadURL: URL
        var size: Int
        var digest: String?

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
            case size
            case digest
        }
    }
}
