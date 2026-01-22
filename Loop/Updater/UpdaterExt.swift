//
//  UpdaterExt.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import CryptoKit
import Foundation

// MARK: - Int64

public extension Int64 {
    var formattedBytes: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.isAdaptive = false // Always use MB, no GB/KB
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: self)
    }
}

// MARK: - UInt32

public extension UInt32 {
    var formattedBytes: String {
        Int64(self).formattedBytes
    }
}

// MARK: - UInt64

public extension UInt64 {
    var formattedBytes: String {
        Int64(clamping: self).formattedBytes
    }
}

// MARK: - String

public extension String {
    func hashed() -> String {
        SHA256.hash(data: Data(utf8)).compactMap { String(format: "%02x", $0) }.joined().prefix(16).uppercased()
    }
}

// MARK: - DateFormatter

public extension DateFormatter {
    static let backupFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()

    func configured(_ configure: (DateFormatter) -> ()) -> DateFormatter {
        configure(self)
        return self
    }
}

// MARK: - Models

// Extension to Release to extract version details from the title
extension Release {
    func extractPrereleaseVersionFromTitle() -> (preRelease: String, buildNumber: Int)? {
        let regex = /🧪 (?<version>.*?) \((?<build>\d+)\)/
        guard let match = name.firstMatch(of: regex) else {
            return nil
        }

        let release = String(match.version)
        let buildNumber = Int(String(match.build)) ?? 0

        return (release, buildNumber)
    }

    // Convert UpdateManifest to Release for UI compatibility
    static func from(manifest: UpdateManifest) -> Release {
        let asset = Release.Asset(
            name: "Loop-\(manifest.version).zip",
            browserDownloadURL: URL(string: manifest.downloadUrl)!,
            size: Int(manifest.size),
            digest: manifest.checksums.zip.isEmpty ? nil : "sha256:\(manifest.checksums.zip)"
        )

        return Release(
            id: 0, // Not used in UI
            tagName: manifest.version,
            name: manifest.releaseNotes.title,
            body: manifest.releaseNotes.body,
            assets: [asset],
            prerelease: manifest.channel != .stable,
            createdAt: manifest.publishedAt,
            updatedAt: manifest.publishedAt,
            publishedAt: manifest.publishedAt,
            buildNumber: manifest.buildNumber
        )
    }
}
