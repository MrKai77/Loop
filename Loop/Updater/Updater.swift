//
//  Updater.swift
//  Loop
//
//  Created by Kami on 11/5/2024.
//

import Combine
import Luminare
import SwiftUI

class Updater: ObservableObject {
    @Published var availableReleases = [Release]()
    @Published var progressBar: Double = 0
    @Published var updateState: UpdateAvailability = .notChecked

    @Published var changelog: [(title: String, body: [String])] = .init()

    enum UpdateAvailability {
        case notChecked
        case available
        case unavailable
    }

    private var windowController: NSWindowController?
    private var updateCheckCancellable: AnyCancellable?

    @Published var includeDevelopmentVersions: Bool = false {
        didSet {
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
                    self.showUpdateWindow()
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

    // Optimized processFetchedData function
    private func processFetchedData(_ data: Data) async throws {
        let decoder = JSONDecoder()
        // Decode the data based on the flag includeDevelopmentVersions.
        if includeDevelopmentVersions {
            let releases = try decoder.decode([Release].self, from: data)
            // Use compactMap to find the first prerelease and process it, if any.
            if let latestPreRelease = releases.compactMap({ $0.prerelease ? $0 : nil }).first {
                try await processRelease(latestPreRelease)
            }
        } else {
            // Decode directly into a single Release object.
            let release = try decoder.decode(Release.self, from: data)
            try await processRelease(release)
        }
    }

    // processRelease function with build number check
    private func processRelease(_ release: Release) async throws {
        let currentVersion = Bundle.main.appVersion
        let currentBuildNumber = Bundle.main.appBuild

        await MainActor.run {
            let isVersionUpdateAvailable = release.tagName.compare(currentVersion, options: .numeric) == .orderedDescending
            var isUpdateAvailable = isVersionUpdateAvailable

            // Extract the build number from the release body if it's a developmental version
            var releaseBuildNumber: String?
            if includeDevelopmentVersions {
                let versionDetails = release.extractVersionDetailsFromBody()
                releaseBuildNumber = versionDetails.buildNumber
                if let releaseBuild = releaseBuildNumber.flatMap(Int.init), let currentBuild = Int(currentBuildNumber) {
                    isUpdateAvailable = isUpdateAvailable || releaseBuild > currentBuild
                }
            }

            updateState = isUpdateAvailable ? .available : .unavailable
            if isUpdateAvailable {
                // If the developmental branch is chosen and has a higher build number, use its build number.
                // Create a new Release object with the updated build number
                var updatedRelease = release
                updatedRelease.buildNumber = releaseBuildNumber
                availableReleases = [updatedRelease] // Use the release with the potentially updated build number
                processChangelog(updatedRelease.body) // Use the updated release body
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
                guard line.hasPrefix("- ") else { continue }

                // Format list items
                let line = line
                    .replacingOccurrences(of: "- ", with: "") // Remove bullet point
                    .replacingOccurrences(of: #"#\d+ "#, with: "", options: .regularExpression) // Remove issue number
                    .replacingOccurrences(of: #"\(@.*\)"#, with: "", options: .regularExpression) // Remove author
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if let index = changelog.firstIndex(where: { $0.title == currentSection }) {
                    changelog[index].body.append(line)
                }
            }
        }
    }

    // Checks if the fetched release is newer than the current version and updates the app state.
    func showUpdateWindow() {
        if updateState == .available {
            if windowController?.window == nil {
                windowController = .init(window: LuminareTrafficLightedWindow { UpdateView() })
            }
            windowController?.window?.makeKeyAndOrderFront(self)
            windowController?.window?.orderFrontRegardless()
        }
    }

    // Downloads the update from GitHub and prepares it for installation.
    func installUpdate() async {
        guard
            let latestRelease = availableReleases.first,
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
    var title: String?
    var body: String
    var assets: [Asset]
    var prerelease: Bool
    var buildNumber: String?

    enum CodingKeys: String, CodingKey {
        case id, tagName = "tag_name", title, body, assets, prerelease
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

// Extension to Release to extract version details from the body
extension Release {
    // Function to extract version details from the body
    func extractVersionDetailsFromBody() -> (preRelease: String?, buildNumber: String?) {
        let pattern = "Version: (.*?) \\((\\d+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)) else {
            return (nil, nil)
        }

        let preRelease = Range(match.range(at: 1), in: body).flatMap { String(self.body[$0]) }
        let buildNumber = Range(match.range(at: 2), in: body).flatMap { String(self.body[$0]) }

        return (preRelease, buildNumber)
    }
}
