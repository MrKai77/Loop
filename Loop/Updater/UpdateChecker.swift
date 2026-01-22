//
//  UpdateChecker.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import Foundation
import Scribe

@Loggable(style: .static)
public class UpdateChecker: @unchecked Sendable {
    private let config: UpdaterConfig
    private let httpClient: HTTPClient

    public init(config: UpdaterConfig) {
        self.config = config
        self.httpClient = HTTPClient(config: config)
    }

    public func checkForUpdate(
        bundleId: String,
        currentVersion: String,
        currentBuild: Int = 0,
        channel: UpdateChannel,
        force: Bool = false
    ) async throws -> UpdateManifest? {
        Log.info("Checking for updates: \(bundleId) v\(currentVersion) build \(currentBuild) [\(channel.rawValue)]")

        let endpoint = URL(string: channel.githubReleasesEndpoint)!

        do {
            let manifestData = try await httpClient.fetchData(from: endpoint)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            if channel == .stable {
                // Single release
                let release = try decoder.decode(Release.self, from: manifestData)
                return try processRelease(release, currentVersion: currentVersion, currentBuild: currentBuild, force: force)
            } else {
                // Multiple releases for beta channel
                let releases = try decoder.decode([Release].self, from: manifestData)
                if let latestBetaRelease = releases.first(where: { $0.prerelease }) {
                    return try processRelease(latestBetaRelease, currentVersion: currentVersion, currentBuild: currentBuild, force: force)
                }
            }

            Log.info("No update available")
            return nil

        } catch {
            Log.error("Update check failed: \(error)")
            throw UpdateError.network(error)
        }
    }

    private func processRelease(_ release: Release, currentVersion: String, currentBuild: Int, force: Bool) throws -> UpdateManifest? {
        Log.debug("Processing release: tagName='\(release.tagName)', name='\(release.name)', prerelease=\(release.prerelease)")

        // Extract version and build number from release
        let (comparisonVersion, plistVersion, buildNumber) = extractVersionInfo(from: release)
        Log.debug("Extracted comparison version: \(comparisonVersion), plist version: \(plistVersion), build: \(buildNumber)")

        // Check if this is actually a newer version
        Log.debug("Checking version: force=\(force), current=\(currentVersion) build \(currentBuild), available=\(comparisonVersion) build \(buildNumber)")
        if !force, !isNewerVersion(comparisonVersion, buildNumber: buildNumber, than: currentVersion, currentBuild: currentBuild) {
            Log.info("No newer version available (current: \(currentVersion) build \(currentBuild), available: \(comparisonVersion) build \(buildNumber))")
            return nil
        }

        guard let asset = release.assets.first(where: { $0.name.hasSuffix(".zip") }) else {
            Log.error("No ZIP asset found in release")
            return nil
        }

        // Extract checksum from asset digest (format: "sha256:checksum")
        let zipChecksum = asset.digest?.replacingOccurrences(of: "sha256:", with: "") ?? ""
        Log.debug("Asset digest: \(asset.digest ?? "none"), extracted checksum: \(zipChecksum)")

        let manifest = UpdateManifest(
            version: plistVersion,
            buildNumber: buildNumber,
            downloadUrl: asset.browserDownloadURL.absoluteString,
            releaseNotes: UpdateManifest.ReleaseNotes(
                title: release.name,
                body: release.body,
                compatibility: UpdateManifest.ReleaseNotes.Compatibility(
                    downloadSize: Int64(asset.size),
                    minimumOS: "13.0",
                    maximumOS: nil,
                    supportedArchitectures: ["arm64", "x86_64"]
                )
            ),
            checksums: UpdateManifest.Checksums(
                zip: zipChecksum
            ),
            minimumOS: "13.0",
            channel: release.prerelease ? .beta : .stable,
            publishedAt: release.createdAt,
            size: Int64(asset.size)
        )

        Log.info("Found update: v\(manifest.version) (build \(manifest.buildNumber))")
        return manifest
    }

    private func extractVersionInfo(from release: Release) -> (comparisonVersion: String, plistVersion: String, buildNumber: Int) {
        if release.prerelease {
            // Parse from name field like "🧪 1.4.1 (1683)"
            let regex = /🧪\s+(\d+\.\d+\.\d+)\s+\((\d+)\)/
            if let match = release.name.firstMatch(of: regex) {
                let version = String(match.1)
                let build = Int(String(match.2)) ?? 0
                Log.debug("Parsed prerelease: version=\(version), build=\(build)")
                return (version, version, build)
            }
            Log.warn("Could not parse prerelease version from: '\(release.name)'")
            return ("0.0.0", "0.0.0", 0)
        } else {
            // Stable release: tagName is the version
            return (release.tagName, release.tagName, 0)
        }
    }

    private func isNewerVersion(_ newVersion: String, buildNumber: Int, than currentVersion: String, currentBuild: Int) -> Bool {
        let versionComparison = newVersion.compare(currentVersion, options: .numeric)

        if versionComparison == .orderedDescending {
            return true
        } else if versionComparison == .orderedSame {
            // For same version, only consider it newer if:
            // 1. The release has a meaningful build number (> 0), AND
            // 2. That build number is actually higher than current
            // This prevents stable releases with build=0 from triggering updates for dev builds
            return buildNumber > 0 && buildNumber > currentBuild
        }

        return false
    }
}
