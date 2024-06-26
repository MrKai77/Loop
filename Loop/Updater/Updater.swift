//
//  Updater.swift
//  Loop
//
//  Created by Kami on 11/5/2024.
//

import Combine
import Defaults
import Luminare
import SwiftUI

class Updater: ObservableObject {
    @Published var targetRelease: Release?
    @Published var progressBar: Double = 0
    @Published var updateState: UpdateAvailability = .notChecked

    @Published var changelog: [(title: String, body: [ChangelogNote])] = .init()

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
    }

    private var windowController: NSWindowController?
    private var updateCheckCancellable: AnyCancellable?

    @Published var includeDevelopmentVersions: Bool = Defaults[.includeDevelopmentVersions] {
        didSet {
            Defaults[.includeDevelopmentVersions] = includeDevelopmentVersions

            // When the value changes, trigger a new update check
            Task {
                await fetchLatestInfo()
            }
        }
    }

    init() {
        self.updateCheckCancellable = Timer.publish(every: 21600, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                Task {
                    await self.fetchLatestInfo()

                    if self.updateState == .available {
                        await self.showUpdateWindow()
                    }
                }
            }
    }

    func dismissWindow() {
        DispatchQueue.main.async {
            self.updateState = .notChecked
            self.windowController?.close()
        }
    }

    // Pulls the latest release information from GitHub and updates the app state accordingly.
    func fetchLatestInfo() async {
        await MainActor.run {
            targetRelease = nil
            updateState = .notChecked
            progressBar = 0
        }

        let urlString = includeDevelopmentVersions ?
            "https://api.github.com/repos/MrKai77/Loop/releases" : // Developmental branch
            "https://api.github.com/repos/MrKai77/Loop/releases/latest" // Stable branch

        guard let url = URL(string: urlString) else {
            NSLog("Invalid URL: \(urlString)")
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            // Process data immediately after fetching, reducing the number of async suspension points.
            try await processFetchedData(data)
        } catch {
            NSLog("Error fetching release info: \(error.localizedDescription)")
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
        let currentVersion = Bundle.main.appVersion ?? "0.0.0"

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
                targetRelease = release
                processChangelog(release.body)
            }
        }
    }

    func processChangelog(_ body: String) {
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

                let line = String(line)
                    .replacingOccurrences(of: "- ", with: "") // Remove bullet point
                    .trimmingCharacters(in: .whitespaces)

                var user: String?
                if let regex = try? NSRegularExpression(pattern: #"\(@(.*)\)"#),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                    user = Range(match.range(at: 1), in: line).flatMap { String(line[$0]) }
                }

                var reference: Int?
                if let regex = try? NSRegularExpression(pattern: #"#(\d+) "#),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                    reference = Int(Range(match.range(at: 1), in: line).flatMap { String(line[$0]) } ?? "")
                }

                let emoji = String(line.prefix(1))

                let text = line
                    .suffix(line.count - 1)
                    .replacingOccurrences(of: #"#\d+ "#, with: "", options: .regularExpression) // Remove issue number
                    .replacingOccurrences(of: #"\(@.*\)"#, with: "", options: .regularExpression) // Remove author
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                changelog[index].body.append(.init(emoji: emoji, text: text, user: user, reference: reference))
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
            DispatchQueue.main.async {
                self.progressBar = 0
            }
            return
        }

        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(asset.name)

        DispatchQueue.main.async {
            self.progressBar = 0.2
        }

        if !FileManager.default.fileExists(atPath: destinationURL.path) {
            await downloadUpdate(asset, to: destinationURL)
        }

        unzipAndReplace(downloadedFileURL: destinationURL.path)
    }

    private func downloadUpdate(_ asset: Release.Asset, to destinationURL: URL) async {
        guard let url = URL(string: asset.browserDownloadURL) else {
            return
        }

        do {
            let (fileURL, _) = try await URLSession.shared.download(from: url)

            try FileManager.default.moveItem(at: fileURL, to: destinationURL)

            DispatchQueue.main.async {
                self.progressBar = 0.2
                self.unzipAndReplace(downloadedFileURL: destinationURL.path)
            }
        } catch {
            NSLog("Error: \(error.localizedDescription)")
        }
    }

    private func unzipAndReplace(downloadedFileURL fileURL: String) {
        let appDirectory = Bundle.main.bundleURL.deletingLastPathComponent()
        let appBundle = Bundle.main.bundleURL
        let fileManager = FileManager.default

        do {
            // Unzip the downloaded file and replace the existing app.
            DispatchQueue.main.async {
                self.progressBar = 0.4
            }
            try fileManager.removeItem(at: appBundle)

            DispatchQueue.main.async {
                self.progressBar = 0.6
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-xk", fileURL, appDirectory.path]

            // Run the unzip process.
            try process.run()
            process.waitUntilExit()

            DispatchQueue.main.async {
                self.progressBar = 0.8
                try? fileManager.removeItem(atPath: fileURL) // Clean up the zip file after extraction.
                self.progressBar = 1.0
                self.updateState = .unavailable // Update the state to reflect that the update has been applied.
            }
        } catch {
            DispatchQueue.main.async {
                NSLog("Error updating the app: \(error)")
            }
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
        var browserDownloadURL: String

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
