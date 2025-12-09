//
//  Updater.swift
//  Loop
//
//  Created by Kami on 11/5/2024.
//

import Defaults
import Luminare
import Scribe
import SwiftUI

final class Updater: ObservableObject {
    static let shared = Updater()

    @Published private(set) var targetRelease: Release?
    @Published private(set) var progressBar: Double = 0
    @Published private(set) var updateState: UpdateAvailability = .notChecked
    @Published private(set) var changelog: [(title: String, body: [ChangelogNote])] = .init()
    @Published private(set) var updatesEnabled: Bool = Updater.checkIfUpdatesEnabled()

    private var windowController: NSWindowController?
    private var includeDevelopmentVersions: Bool { Defaults[.includeDevelopmentVersions] }

    private var updateFetcherTask: Task<(), Never>?
    private var updateCheckerTask: Task<(), Never>?
    private var includeDevelopmentVersionsObserver: Task<(), Never>?
    private var updatesEnabledObserver: Task<(), Never>?

    struct ChangelogNote: Identifiable {
        var id: UUID = .init()
        var emoji: String
        var text: String
        var user: String?
        var reference: Int?
    }

    enum UpdateAvailability {
        case notChecked
        case available
        case unavailable
        case disabled
    }

    private init() {
        // Only set up the timer if updates are enabled and env var is not set
        if updatesEnabled {
            self.updateCheckerTask = makeUpdateCheckerTask()
            self.includeDevelopmentVersionsObserver = makeIncludeDevelopmentVersionsObserver()
        } else {
            self.updateState = .disabled
        }

        self.updatesEnabledObserver = makeUpdatesEnabledObserver()
    }

    private static func checkIfUpdatesEnabled() -> Bool {
        if let env = ProcessInfo.processInfo.environment["LOOP_SKIP_UPDATE_CHECK"],
           env == "1" || env.lowercased() == "true" {
            return false
        }
        return Defaults[.updatesEnabled]
    }

    private func makeUpdateCheckerTask() -> Task<(), Never>? {
        Task {
            while !Task.isCancelled {
                // 6 hours
                try? await Task.sleep(for: .seconds(21600))

                await self.fetchLatestInfo()

                if self.updateState == .available {
                    await self.showUpdateWindow()
                }
            }
        }
    }

    private func makeIncludeDevelopmentVersionsObserver() -> Task<(), Never>? {
        Task {
            for await _ in Defaults.updates(.includeDevelopmentVersions, initial: false) {
                guard !Task.isCancelled else { break }
                await fetchLatestInfo()
            }
        }
    }

    private func makeUpdatesEnabledObserver() -> Task<(), Never>? {
        Task {
            for await _ in Defaults.updates(.updatesEnabled) {
                guard !Task.isCancelled else { break }

                await MainActor.run {
                    updatesEnabled = Updater.checkIfUpdatesEnabled()
                }

                if updatesEnabled {
                    self.updateCheckerTask = makeUpdateCheckerTask()
                    self.includeDevelopmentVersionsObserver = makeIncludeDevelopmentVersionsObserver()
                } else {
                    self.updateCheckerTask?.cancel()
                    self.includeDevelopmentVersionsObserver?.cancel()
                    self.updateCheckerTask = nil
                    self.includeDevelopmentVersionsObserver = nil

                    await MainActor.run {
                        targetRelease = nil
                        updateState = .disabled
                        progressBar = 0
                    }
                }
            }
        }
    }

    @MainActor
    func dismissWindow() {
        windowController?.close()
    }

    // Pulls the latest release information from GitHub and updates the app state accordingly.
    func fetchLatestInfo(force: Bool = false) async {
        if let updateFetcherTask {
            return await updateFetcherTask.value // If already fetching, wait for it to finish
        }

        updateFetcherTask = Task {
            defer { updateFetcherTask = nil }

            // Early return if updates are disabled and not forcing
            guard updatesEnabled || force else {
                await MainActor.run {
                    targetRelease = nil
                    updateState = .disabled
                }
                return
            }

            Log.info("Fetching latest release info...", category: .updater)

            await MainActor.run {
                targetRelease = nil
                updateState = .notChecked
                progressBar = 0
            }

            let urlString = includeDevelopmentVersions ?
                "https://api.github.com/repos/MrKai77/Loop/releases" : // Developmental branch
                "https://api.github.com/repos/MrKai77/Loop/releases/latest" // Stable branch

            guard let url = URL(string: urlString) else {
                Log.error("Invalid URL: \(urlString)", category: .updater)
                return
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)

                // Process data immediately after fetching, reducing the number of async suspension points.
                try await processFetchedData(data)
            } catch {
                Log.error("Error fetching release info: \(error.localizedDescription)", category: .updater)
            }
        }

        if let task = updateFetcherTask {
            return await task.value
        }
    }

    private func processFetchedData(_ data: Data) async throws {
        let decoder = JSONDecoder()
        if includeDevelopmentVersions {
            // This would need to parse a list of releases
            let releases = try decoder.decode([Release].self, from: data)

            if let latestPreRelease = releases.compactMap({ $0.prerelease ? $0 : nil }).first {
                try await processRelease(latestPreRelease)
            }
        } else {
            // This would need to parse a single release
            let release = try decoder.decode(Release.self, from: data)
            try await processRelease(release)
        }
    }

    private func processRelease(_ release: Release) async throws {
        let currentVersion = Bundle.main.appVersion?.filter(\.isASCII).trimmingCharacters(in: .whitespaces) ?? "0.0.0"

        await MainActor.run {
            var release = release

            if release.prerelease,
               let versionDetails = release.extractPrereleaseVersionFromTitle() {
                release.tagName = versionDetails.preRelease
                release.buildNumber = versionDetails.buildNumber
            }

            var isUpdateAvailable = release.tagName.compare(currentVersion, options: .numeric) == .orderedDescending

            // If the development version is chosen, compare the build number
            if !isUpdateAvailable,
               includeDevelopmentVersions,
               let versionBuild = release.buildNumber,
               let currentBuild = Bundle.main.appBuild {
                isUpdateAvailable = versionBuild > currentBuild
            }

            updateState = isUpdateAvailable ? .available : .unavailable

            if isUpdateAvailable {
                Log.notice("Update available: \(release.name)", category: .updater)

                targetRelease = release
                processChangelog(release.body)
            }
        }
    }

    private func processChangelog(_ body: String) {
        changelog = .init()

        let lines = body
            .split(whereSeparator: \.isNewline)

        var currentSection: String?

        for line in lines where !line.isEmpty {
            if line.starts(with: "#") {
                currentSection = line
                    .replacing(/#/, with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if changelog.first(where: { $0.title == currentSection }) == nil {
                    changelog.append((title: currentSection!, body: []))
                }
            } else {
                guard
                    line.hasPrefix("- "),
                    let index = changelog.firstIndex(where: { $0.title == currentSection })
                else {
                    continue
                }

                let cleanedLine = line
                    .replacing(#/- /#, with: "")
                    .trimmingCharacters(in: .whitespaces)

                let user: String?
                let reference: Int?

                if let match = cleanedLine.firstMatch(of: /(@(?<user>\w+))/) {
                    user = String(match.user)
                } else {
                    user = nil
                }

                if let match = cleanedLine.firstMatch(of: /#(?<reference>\d+)/) {
                    reference = Int(String(match.reference))
                } else {
                    reference = nil
                }

                /// Use `isEmojiPresentation` instead of `isEmoji` to ensure that `#`s are excluded.
                let emoji = cleanedLine.unicodeScalars.first(where: \.properties.isEmojiPresentation) ?? currentSection?.unicodeScalars.first(where: \.properties.isEmojiPresentation) ?? "🔄"

                let text = cleanedLine
                    .drop(while: { $0.unicodeScalars.first?.properties.isEmojiPresentation == true }) // Emojis
                    .replacing(#/#\d+/#, with: "") // Issue #
                    .replacing(#/(@.*?)/#, with: "") // Mentions
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                changelog[index].body.append(.init(
                    emoji: String(emoji),
                    text: text,
                    user: user,
                    reference: reference
                ))
            }
        }
    }

    func showUpdateWindow() async {
        guard updateState == .available else { return }

        await MainActor.run {
            if windowController?.window == nil {
                windowController = .init(window: LuminareTrafficLightedWindow { UpdateView() })
            }
            windowController?.window?.makeKeyAndOrderFront(self)
            windowController?.window?.orderFrontRegardless()
        }
    }

    // Downloads the update from GitHub and installs it
    func installUpdate() async {
        guard
            let latestRelease = targetRelease,
            let asset = latestRelease.assets.first
        else {
            await MainActor.run {
                self.progressBar = 0
            }
            return
        }

        Log.info("Installing update: \(latestRelease.name)", category: .updater)

        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("\(asset.name)_\(latestRelease.tagName)")

        await MainActor.run {
            self.progressBar = 0.25
        }

        if !FileManager.default.fileExists(atPath: tempUrl.path) {
            await downloadUpdate(asset, to: tempUrl)
        }

        await MainActor.run {
            self.progressBar = 0.75
        }

        await unzipAndSwap(downloadedFileURL: tempUrl.path)

        try? FileManager.default.removeItem(at: tempUrl)

        await MainActor.run {
            self.progressBar = 1.0
            self.updateState = .unavailable
        }

        Log.info("Update installed successfully", category: .updater)
    }

    private func downloadUpdate(_ asset: Release.Asset, to destinationURL: URL) async {
        Log.info("Downloading update asset: \(asset.name) to \(destinationURL.path)", category: .updater)

        do {
            let (fileURL, _) = try await URLSession.shared.download(from: asset.browserDownloadURL)
            try FileManager.default.moveItem(at: fileURL, to: destinationURL)
        } catch {
            Log.error("Failed to download update: \(error.localizedDescription)", category: .updater)
        }
    }

    private func unzipAndSwap(downloadedFileURL fileURL: String) async {
        Log.info("Unzipping and swapping app bundle at \(fileURL)", category: .updater)

        let appBundle = Bundle.main.bundleURL
        let fileManager = FileManager.default

        do {
            // Create a temporary directory
            // It's ideal to keep this separate from the fileURL since this is where the swapping happens, and
            // if this fails, it can't affect the original downloaded zip file.
            let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Unzip to a temp directory
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-xk", fileURL, tempDir.path]
            try process.run()
            process.waitUntilExit()

            // Find the unzipped app bundle
            let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            guard let newAppBundle = contents.first(where: { $0.pathExtension == "app" }) else {
                Log.error("No app bundle found in extracted contents", category: .updater)
                return
            }

            // Atomically swap the old app bundle with the new one
            _ = try fileManager.replaceItemAt(
                appBundle,
                withItemAt: newAppBundle,
                backupItemName: nil,
                options: [.usingNewMetadataOnly]
            )

            // Clean up
            try fileManager.removeItem(at: tempDir)
        } catch {
            Log.error("Error updating the app: \(error.localizedDescription)", category: .updater)
        }
    }
}

// MARK: - Models

// Release model to parse GitHub API response for releases.
struct Release: Codable {
    var id: Int
    var tagName: String
    var name: String
    var body: String
    var assets: [Asset]
    var prerelease: Bool

    var buildNumber: Int?

    enum CodingKeys: String, CodingKey {
        case id, tagName = "tag_name", name, body, assets, prerelease
    }

    struct Asset: Codable {
        var name: String
        var browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }
}

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
}
