//
//  Updater.swift
//  Loop
//
//  Created by Kami on 11/5/2024.
//

import SwiftUI
import Luminare

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

    // Provides a modified version of the release notes body for display purposes.
    var modifiedBody: String {
        body
            .replacingOccurrences(of: "- [x]", with: ">")
            .replacingOccurrences(of: "###", with: "")
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

// MARK: - Updater Functionality

// Updater class provides functionality to check for and apply updates.
class Updater {
    static var updateWindow: NSWindow?

    // Pulls the latest release information from GitHub and updates the app state accordingly.
    func pullFromGitHub(appState: AppState, manual: Bool = false, releaseOnly: Bool = false) {
        guard let url = URL(string: "https://api.github.com/repos/MrKai77/Loop/releases/latest") else { return }

        // Asynchronous network call to fetch release data.
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data else {
                DispatchQueue.main.async {
                    NSLog("Fetch failed: \(error?.localizedDescription ?? "Unknown error")")
                }
                return
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(Release.self, from: data)

                DispatchQueue.main.async {
                    appState.releases = [decodedResponse]
                    appState.changelogText = decodedResponse.modifiedBody

                    // If not releaseOnly, proceed to check for an update.
                    if !releaseOnly {
                        self?.checkForUpdate(appState: appState, manual: manual)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    NSLog("JSON decoding error: \(error.localizedDescription)")
                }
            }
        }
        .resume()
    }

    // Dismisses the update window and updates the app state.
    func dismissUpdateWindow(appState: AppState) {
        DispatchQueue.main.async {
            appState.updateAvailable = false
            Updater.updateWindow?.close()
        }
    }

    // Checks if the fetched release is newer than the current version and updates the app state.
    func checkForUpdate(appState: AppState, manual: Bool) {
        guard let latestRelease = appState.releases.first else {
            if manual {
                DispatchQueue.main.async {
                    // TODO: edit view for when no updates are available
                    Updater.updateWindow = LuminareTrafficLightedWindow {
                        UpdateView()
                            .environmentObject(appState)
                    }
                }
            }
            return
        }

        let currentVersion = Bundle.main.appVersion
        let updateIsNeeded = latestRelease.tagName.compare(currentVersion, options: .numeric) == .orderedDescending

        DispatchQueue.main.async {
            appState.updateAvailable = updateIsNeeded

            // If manual check and no update is needed, show the no update window.
            if manual, !updateIsNeeded {
                Updater.updateWindow = LuminareTrafficLightedWindow {
                    UpdateView()
                        .environmentObject(appState)
                }
            }
        }
    }

    // Downloads the update from GitHub and prepares it for installation.
    func downloadUpdate(appState: AppState) {
        guard let latestRelease = appState.releases.first,
              let asset = latestRelease.assets.first,
              let url = URL(string: asset.browserDownloadURL)
        else {
            DispatchQueue.main.async {
                appState.progressBar = ("", 0)
            }
            return
        }

        let fileManager = FileManager.default
        let destinationURL = fileManager.temporaryDirectory.appendingPathComponent(asset.name)

        // If the update file already exists, proceed to unzip and replace the app.
        if fileManager.fileExists(atPath: destinationURL.path) {
            DispatchQueue.main.async {
                appState.progressBar = ("", 1.0)
                self.unzipAndReplace(downloadedFileURL: destinationURL.path, appState: appState)
            }
            return
        }

        // Start the download and update the progress bar.
        DispatchQueue.main.async {
            appState.progressBar = ("", 0.1)
        }

        // Download task for the update file.
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        URLSession.shared.downloadTask(with: request) { [weak self] localURL, _, error in
            guard let localURL else {
                DispatchQueue.main.async {
                    NSLog("Download error: \(error?.localizedDescription ?? "Unknown error")")
                }
                return
            }

            do {
                // Move the downloaded file to the temporary directory.
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: localURL, to: destinationURL)
                DispatchQueue.main.async {
                    appState.progressBar = ("", 0.5)
                    self?.unzipAndReplace(downloadedFileURL: destinationURL.path, appState: appState)
                }
            } catch {
                DispatchQueue.main.async {
                    NSLog("File operation error: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    // Unzips the downloaded update and replaces the current app with the new version.
    func unzipAndReplace(downloadedFileURL fileURL: String, appState: AppState) {
        let appDirectory = Bundle.main.bundleURL.deletingLastPathComponent()
        let appBundle = Bundle.main.bundleURL
        let fileManager = FileManager.default

        do {
            // Unzip the downloaded file and replace the existing app.
            DispatchQueue.main.async {
                appState.progressBar = ("", 0.5)
            }
            try fileManager.removeItem(at: appBundle)

            DispatchQueue.main.async {
                appState.progressBar = ("", 0.6)
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-xk", fileURL, appDirectory.path]

            // Run the unzip process.
            try process.run()
            process.waitUntilExit()

            DispatchQueue.main.async {
                appState.progressBar = ("", 0.8)
                try? fileManager.removeItem(atPath: fileURL) // Clean up the zip file after extraction.
                appState.progressBar = ("", 1.0)
                appState.updateAvailable = false // Update the state to reflect that the update has been applied.
            }
        } catch {
            DispatchQueue.main.async {
                NSLog("Error updating the app: \(error)")
            }
        }
    }
}
