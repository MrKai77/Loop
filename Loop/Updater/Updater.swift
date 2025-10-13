//
//  Updater.swift
//  Loop
//
//  Created by Kami on 11/5/2024.
//

import Defaults
import Luminare
import OSLog
import SwiftUI

final class Updater: ObservableObject {
    static let shared = Updater()

    @Published private(set) var targetRelease: Release?
    @Published private(set) var progressBar: Double = 0
    @Published private(set) var updateState: UpdateAvailability = .notChecked
    @Published private(set) var changelog: [(title: String, body: [ChangelogNote])] = .init()
    @Published private(set) var updatesEnabled: Bool = Updater.checkIfUpdatesEnabled()

    private let logger = Logger(category: "Updater")
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
                await self.fetchLatestInfo()

                if self.updateState == .available {
                    await self.showUpdateWindow()
                }

                // 6 hours
                try? await Task.sleep(for: .seconds(21600))
            }
        }
    }

    private func makeIncludeDevelopmentVersionsObserver() -> Task<(), Never>? {
        Task {
            for await _ in Defaults.updates(.includeDevelopmentVersions) {
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

            logger.info("Fetching latest release info...")

            await MainActor.run {
                targetRelease = nil
                updateState = .notChecked
                progressBar = 0
            }

            let urlString = includeDevelopmentVersions ?
                "https://api.github.com/repos/MrKai77/Loop/releases" : // Developmental branch
                "https://api.github.com/repos/MrKai77/Loop/releases/latest" // Stable branch

            guard let url = URL(string: urlString) else {
                logger.error("Invalid URL: \(urlString)")
                return
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)

                // Process data immediately after fetching, reducing the number of async suspension points.
                try await processFetchedData(data)
            } catch {
                logger.error("Error fetching release info: \(error.localizedDescription)")
            }
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
               let versionDetails = release.extractVersionFromTitle() {
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
                logger.info("Update available: \(release.name)")

                targetRelease = release
                processChangelog(release.body)
            }
        }
    }

    private func processChangelog(_ body: String) {
        changelog = .init()

        let lines = body
            .replacingOccurrences(of: "\r", with: "")
            .split(separator: "\n")

        var currentSection: String?

        for line in lines {
            if line.starts(with: "#") {
                currentSection = line
                    .replacingOccurrences(of: "#", with: "")
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

                let cleanedLine = String(line)
                    .replacingOccurrences(of: "- ", with: "")
                    .trimmingCharacters(in: .whitespaces)

                let user = try? NSRegularExpression(pattern: #"\(@(.*?)\)"#)
                    .firstMatch(in: cleanedLine, range: NSRange(cleanedLine.startIndex..., in: cleanedLine))
                    .flatMap { Range($0.range(at: 1), in: cleanedLine).map { String(cleanedLine[$0]) } }

                let reference = try? NSRegularExpression(pattern: #"#(\d+)"#)
                    .firstMatch(in: cleanedLine, range: NSRange(cleanedLine.startIndex..., in: cleanedLine))
                    .flatMap { Range($0.range(at: 1), in: cleanedLine).flatMap { Int(cleanedLine[$0]) } }

                /// we should use `isEmojiPresentation` instead of `isEmoji` to ensure that `#`s are excluded.
                let emoji = cleanedLine.unicodeScalars.first(where: \.properties.isEmojiPresentation) ?? currentSection?.unicodeScalars.first(where: \.properties.isEmojiPresentation) ?? "🔄"

                let text = cleanedLine
                    .drop(while: { $0.unicodeScalars.first?.properties.isEmojiPresentation == true }) // remove any emojis
                    .replacingOccurrences(of: #"#\d+"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"\(@.*?\)"#, with: "", options: .regularExpression)
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

        logger.info("Installing update: \(latestRelease.name)")

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

        logger.info("Update installed successfully")
    }

    private func downloadUpdate(_ asset: Release.Asset, to destinationURL: URL) async {
        logger.info("Downloading update asset: \(asset.name) to \(destinationURL.path)")

        do {
            let (fileURL, _) = try await URLSession.shared.download(from: asset.browserDownloadURL)
            try FileManager.default.moveItem(at: fileURL, to: destinationURL)
        } catch {
            logger.error("Failed to download update: \(error.localizedDescription)")
        }
    }

    private func unzipAndSwap(downloadedFileURL fileURL: String) async {
        logger.info("Unzipping and swapping app bundle at \(fileURL)")

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
                logger.error("No app bundle found in extracted contents")
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
            logger.error("Error updating the app: \(error.localizedDescription)")
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
    func extractVersionFromTitle() -> (preRelease: String, buildNumber: Int)? {
        let pattern = #"🧪 (.*?) \((\d+)\)"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name))
        else {
            return nil
        }

        let preRelease = Range(match.range(at: 1), in: name).flatMap { String(self.name[$0]) } ?? "0.0.0"
        let buildNumber = Int(Range(match.range(at: 2), in: name).flatMap { self.name[$0] } ?? "") ?? 0

        return (preRelease, buildNumber)
    }
}
