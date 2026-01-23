//
//  BundleVersionMatcher.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-23.
//

import Foundation
import Scribe

/// Utility for reading and validating bundle versions against update manifests
@Loggable(style: .static)
enum BundleVersionMatcher {
    /// Version information extracted from a bundle's Info.plist
    struct VersionInfo {
        let version: String
        let build: Int

        /// Returns the normalized version string (removes dev build emoji and trims whitespace)
        var normalizedVersion: String {
            version
                .replacing(/🧪/, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Reads version information from a bundle's Info.plist
    /// - Parameter bundleURL: URL to the app bundle
    /// - Returns: VersionInfo if successfully read, nil otherwise
    static func readVersionInfo(from bundleURL: URL) -> VersionInfo? {
        let infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist")

        guard let plist = NSDictionary(contentsOf: infoPlistURL),
              let version = plist["CFBundleShortVersionString"] as? String,
              let buildString = plist["CFBundleVersion"] as? String,
              let build = Int(buildString) else {
            log.error("Could not read version info from Info.plist at: \(infoPlistURL.path)")
            return nil
        }

        return VersionInfo(version: version, build: build)
    }

    /// Verifies that a bundle's version matches the expected manifest
    /// - Parameters:
    ///   - bundleURL: URL to the app bundle to verify
    ///   - manifest: The update manifest to compare against
    /// - Throws: `UpdateError.installationError` if versions don't match
    static func verifyVersionMatches(bundleURL: URL, manifest: UpdateManifest) throws {
        guard let versionInfo = readVersionInfo(from: bundleURL) else {
            throw UpdateError.installationError("Could not read version info from bundle at: \(bundleURL.path)")
        }

        try verifyVersionMatches(versionInfo: versionInfo, manifest: manifest)
    }

    /// Verifies that version info matches the expected manifest
    /// - Parameters:
    ///   - versionInfo: The version info to verify
    ///   - manifest: The update manifest to compare against
    /// - Throws: `UpdateError.installationError` if versions don't match
    static func verifyVersionMatches(versionInfo: VersionInfo, manifest: UpdateManifest) throws {
        log.info("Verifying version - Bundle: \(versionInfo.version) (\(versionInfo.build)), Expected: \(manifest.version) (\(manifest.buildNumber))")

        guard versionInfo.normalizedVersion == manifest.version else {
            log.error("Version mismatch - Expected: \(manifest.version), Got: \(versionInfo.normalizedVersion)")
            throw UpdateError.installationError("Version mismatch: expected \(manifest.version), got \(versionInfo.normalizedVersion)")
        }

        // For non-stable channels, also verify build number
        if manifest.channel != .stable {
            guard versionInfo.build == manifest.buildNumber else {
                log.error("Build number mismatch - Expected: \(manifest.buildNumber), Got: \(versionInfo.build)")
                throw UpdateError.installationError("Build number mismatch: expected \(manifest.buildNumber), got \(versionInfo.build)")
            }
        }

        log.success("Version verification passed")
    }
}
