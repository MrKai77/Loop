//
//  UpdaterModels.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import Foundation

// MARK: - UpdateChannel

public enum UpdateChannel: String, Sendable, CaseIterable {
    case stable
    case beta

    public var displayName: String {
        switch self {
        case .stable: "Stable"
        case .beta: "Beta"
        }
    }

    public var isDevelopmentChannel: Bool {
        switch self {
        case .stable: false
        case .beta: true
        }
    }

    public var githubReleasesEndpoint: String {
        switch self {
        case .stable: "https://api.github.com/repos/MrKai77/Loop/releases/latest"
        case .beta: "https://api.github.com/repos/MrKai77/Loop/releases"
        }
    }
}

// MARK: - UpdateManifest

public struct UpdateManifest: Sendable {
    public let version: String
    public let buildNumber: Int
    public let downloadUrl: String
    public let releaseNotes: ReleaseNotes
    public let checksums: Checksums
    public let minimumOS: String
    public let channel: UpdateChannel
    public let publishedAt: Date
    public let size: Int64

    public struct ReleaseNotes: Sendable {
        public let title: String
        public let body: String
        public let compatibility: Compatibility

        public struct Compatibility: Sendable {
            public let downloadSize: Int64
            public let minimumOS: String
            public let maximumOS: String?
            public let supportedArchitectures: [String]
        }
    }

    public struct Checksums: Sendable {
        public let zip: String
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

public struct UpdateProgress: Sendable {
    public let phase: UpdatePhase
    public let percentage: Double
    public let bytesDownloaded: Int64
    public let totalBytes: Int64
    public let estimatedTimeRemaining: TimeInterval?
    public let downloadSpeed: Double?

    public enum UpdatePhase: String, Sendable {
        case checking, downloading, extracting, verifying, installing, completed, failed
    }

    public init(
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

public enum UpdateError: LocalizedError, Sendable {
    case networkError(Error)
    case invalidManifest
    case checksumMismatch
    case installationFailed(Error)
    case securityViolation(String)
    case timeout
    case clientError(Int)
    case serverError(Int)

    public var errorDescription: String? {
        switch self {
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        case .invalidManifest:
            "Invalid update manifest"
        case .checksumMismatch:
            "File integrity check failed"
        case let .installationFailed(error):
            "Installation failed: \(error.localizedDescription)"
        case let .securityViolation(reason):
            "Security violation: \(reason)"
        case .timeout:
            "Request timed out"
        case let .clientError(code):
            "Client error (\(code))"
        case let .serverError(code):
            "Server error (\(code))"
        }
    }

    public var isRetryable: Bool {
        switch self {
        case let .networkError(error):
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed:
                    return true
                default:
                    return false
                }
            }
            return false
        case .timeout, .serverError:
            return true
        default:
            return false
        }
    }
}

// MARK: - UpdaterConfig

public struct UpdaterConfig: Sendable {
    public let updateEndpoint: URL
    public let currentBuildNumber: Int
    public let userGroup: String?
    public let networkConfig: NetworkConfig

    public struct SecurityConfig: Sendable {
        public let checksumValidationEnabled: Bool
        public let codeSignatureValidationEnabled: Bool

        public static let `default`: SecurityConfig = .init(
            checksumValidationEnabled: true,
            codeSignatureValidationEnabled: false
        )
    }

    public struct NetworkConfig: Sendable {
        public let timeout: TimeInterval
        public let retryCount: Int
        public let retryDelay: TimeInterval
        public let allowsCellularAccess: Bool

        public static let `default`: NetworkConfig = .init(
            timeout: 30.0,
            retryCount: 3,
            retryDelay: 2.0,
            allowsCellularAccess: true
        )
    }

    public init(
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
