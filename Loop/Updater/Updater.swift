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
    // Make sure to run checkForUpdate() after this if needed.
    func fetchLatestInfo() async {
        guard let url = URL(string: "https://api.github.com/repos/MrKai77/Loop/releases/latest") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(Release.self, from: data)

            availableReleases = [response]

            if let latestRelease = availableReleases.first {
                let currentVersion = Bundle.main.appVersion

                if latestRelease.tagName.compare(currentVersion, options: .numeric) == .orderedDescending {
                    updateState = .available
                    processChangelog(response.body)
                } else {
                    updateState = .unavailable
                }
            }
        } catch {
            NSLog("Error: \(error.localizedDescription)")
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
    let id: Int
    let tagName: String
    let body: String
    let assets: [Release.Asset]

    enum CodingKeys: String, CodingKey {
        case id, body, assets
        case tagName = "tag_name" // Maps JSON key "tag_name" to the property `tagName`.
    }

    struct Asset: Codable {
        let name: String
        let browserDownloadURL: String

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url" // Maps JSON key "browser_download_url" to the property `browserDownloadURL`.
        }
    }
}
