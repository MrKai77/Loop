//
//  UpdateChecker.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import Foundation
import Scribe

@Loggable
final class UpdateChecker: @unchecked Sendable {
    private let config: UpdaterConfig
    private let httpClient: HTTPClient

    private static let minimumOSRegex = /Minimum macOS version:\s*(?<major>\d+)(?:\.(?<minor>\d+))?(?:\.(?<patch>\d+))?/
        .ignoresCase()
    private static let maximumOSRegex = /Maximum macOS version:\s*(?<major>\d+)(?:\.(?<minor>\d+))?(?:\.(?<patch>\d+))?/
        .ignoresCase()

    init(config: UpdaterConfig) {
        self.config = config
        self.httpClient = HTTPClient(config: config)
    }

    func checkForUpdate(
        bundleId: String,
        currentVersion: String,
        currentBuild: Int = 0,
        channel: UpdateChannel
    ) async throws -> UpdateManifest? {
        log.info("Checking for updates: \(bundleId) v\(currentVersion) build \(currentBuild) [\(channel.rawValue)]")

        let endpoint = URL(string: channel.githubReleasesEndpoint)!
        var candidateRelease: Release?

        let manifestData = try await httpClient.fetchData(from: endpoint)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if channel == .stable {
            // Single release
            candidateRelease = try decoder.decode(Release.self, from: manifestData)
        } else {
            // Multiple releases for beta channel
            let releases = try decoder.decode([Release].self, from: manifestData)
            candidateRelease = releases.first(where: { $0.prerelease })
        }

        if let candidateRelease {
            return try processRelease(
                candidateRelease,
                currentVersion: currentVersion,
                currentBuild: currentBuild
            )
        }

        log.info("No update available")
        return nil
    }

    private func processRelease(
        _ release: Release,
        currentVersion: String,
        currentBuild: Int
    ) throws -> UpdateManifest? {
        log.debug("Processing release: tagName='\(release.tagName)', name='\(release.name)', prerelease=\(release.prerelease)")

        // Extract version and build number from release
        let (version, buildNumber) = extractVersionInfo(from: release)

        // Check if this is actually a newer version
        log.debug("Checking version: current='\(currentVersion) (\(currentBuild))', available='\(version) (\(buildNumber))'")
        guard isNewerVersion(
            version,
            buildNumber: buildNumber,
            than: currentVersion,
            currentBuild: currentBuild
        ) else {
            log.info("No newer version available")
            return nil
        }

        guard let asset = release.assets.first(where: { $0.name.hasSuffix(".zip") }) else {
            log.error("No ZIP asset found in release")
            return nil
        }

        // Extract checksum from asset digest (format: "sha256:checksum")
        let zipChecksum = asset.digest?.replacingOccurrences(of: "sha256:", with: "") ?? ""
        log.debug("Asset digest: \(asset.digest ?? "none"), extracted checksum: \(zipChecksum)")

        let (minimumOS, maximumOS) = extractOSRequirements(from: release.body)

        let manifest = UpdateManifest(
            version: version,
            buildNumber: buildNumber,
            downloadUrl: asset.browserDownloadURL.absoluteString,
            releaseNotes: UpdateManifest.ReleaseNotes(
                title: release.name,
                body: release.body
            ),
            checksums: UpdateManifest.Checksums(
                zip: zipChecksum
            ),
            compatibility: UpdateManifest.Compatibility(
                downloadSize: Int64(asset.size),
                minimumOS: minimumOS,
                maximumOS: maximumOS,
                supportedArchitectures: ["arm64", "x86_64"]
            ),
            channel: release.prerelease ? .beta : .stable,
            publishedAt: release.createdAt,
            size: Int64(asset.size)
        )

        // Verify system requirements before returning the manifest
        try verifySystemRequirements(manifest: manifest)

        log.info("Found update: v\(manifest.version) (build \(manifest.buildNumber))")
        return manifest
    }

    private func extractVersionInfo(from release: Release) -> (version: String, buildNumber: Int) {
        if release.prerelease {
            // Parse from name field like "🧪 1.4.1 (1683)"
            let regex = /🧪\s+(\d+\.\d+\.\d+)\s+\((\d+)\)/
            if let match = release.name.firstMatch(of: regex) {
                let version = String(match.1)
                let build = Int(String(match.2)) ?? 0
                log.debug("Parsed prerelease: version=\(version), build=\(build)")
                return (version, build)
            }

            log.warn("Could not parse prerelease version from: '\(release.name)'")
            return ("0.0.0", 0)
        } else {
            // Stable release: tagName is the version
            return (release.tagName, 0)
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

    private func extractOSRequirements(from body: String) -> (minimum: OperatingSystemVersion?, maximum: OperatingSystemVersion?) {
        var minimumOS: OperatingSystemVersion?
        var maximumOS: OperatingSystemVersion?

        for line in body.split(whereSeparator: \.isNewline).reversed() {
            let (minimum, maximum) = extractMacOSVersionRequirements(from: String(line))

            if minimumOS == nil { minimumOS = minimum }
            if maximumOS == nil { maximumOS = maximum }

            if minimumOS != nil, maximumOS != nil { break }
        }

        log.debug("Extracted OS requirements: minimum=\(minimumOS?.description ?? "none"), maximum=\(maximumOS?.description ?? "none")")
        return (minimumOS, maximumOS)
    }

    private func extractMacOSVersionRequirements(from line: String) -> (minimum: OperatingSystemVersion?, maximum: OperatingSystemVersion?) {
        var minimum: OperatingSystemVersion?
        var maximum: OperatingSystemVersion?

        if let match = line.firstMatch(of: Self.minimumOSRegex), let major = Int(match.major) {
            let minor = match.minor.flatMap { Int($0) } ?? 0
            let patch = match.patch.flatMap { Int($0) } ?? 0
            minimum = OperatingSystemVersion(majorVersion: major, minorVersion: minor, patchVersion: patch)
        }

        if let match = line.firstMatch(of: Self.maximumOSRegex), let major = Int(match.major) {
            let minor = match.minor.flatMap { Int($0) } ?? 0
            let patch = match.patch.flatMap { Int($0) } ?? 0
            maximum = OperatingSystemVersion(majorVersion: major, minorVersion: minor, patchVersion: patch)
        }

        return (minimum, maximum)
    }

    private func verifySystemRequirements(manifest: UpdateManifest) throws {
        log.info("Verifying system requirements")

        if let minimumOS = manifest.compatibility.minimumOS {
            guard ProcessInfo.processInfo.isOperatingSystemAtLeast(minimumOS) else {
                throw UpdateError.incompatibleSystem("Update requires macOS \(minimumOS.description) or later")
            }
        }

        if let maximumOS = manifest.compatibility.maximumOS {
            // Maximum OS is inclusive
            // e.g. a max OS of 15.6.1 should allow Loop to be installed on 15.6.1, but not on 15.6.2
            let actualMaximumOS = OperatingSystemVersion(
                majorVersion: maximumOS.majorVersion,
                minorVersion: maximumOS.minorVersion,
                patchVersion: maximumOS.patchVersion + 1
            )

            guard !ProcessInfo.processInfo.isOperatingSystemAtLeast(actualMaximumOS) else {
                throw UpdateError.incompatibleSystem("Update requires macOS \(maximumOS.description) or earlier")
            }
        }

        log.success("System requirements verified")
    }
}
