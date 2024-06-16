//
//  Updater.swift
//  Loop
//
//  Created by Kami on 11/5/2024.
//

import Foundation

// MARK: - Models

// Release model to parse GitHub API response for releases.
struct Release: Codable {
  let id: Int
  let tagName: String
  let body: String
  let assets: [Asset]

  enum CodingKeys: String, CodingKey {
    case id, body, assets
    case tagName = "tag_name"  // Maps JSON key "tag_name" to the property `tagName`.
  }

  // Provides a modified version of the release notes body for display purposes.
  var modifiedBody: String {
    body.replacingOccurrences(of: "- [x]", with: ">").replacingOccurrences(of: "###", with: "")
  }
}

// Asset model to parse the assets array in the GitHub API response.
struct Asset: Codable {
  let name: String
  let browserDownloadURL: String

  enum CodingKeys: String, CodingKey {
    case name
    case browserDownloadURL = "browser_download_url"  // Maps JSON key "browser_download_url" to the property `browserDownloadURL`.
  }
}

// MARK: - Updater Functionality

// Updater class provides functionality to check for and apply updates.
class Updater {
  static let shared = Updater()  // Singleton instance of Updater.
  private init() {}  // Private initializer to enforce singleton usage.

  // Pulls the latest release information from GitHub and updates the app state accordingly.
  func pullFromGitHub(appState: AppState, manual: Bool = false, releaseOnly: Bool = false) {
    // GitHub API URL for the latest release of the repository.
    let urlString = "https://api.github.com/repos/MrKai77/Loop/releases/latest"
    guard let url = URL(string: urlString) else { return }

    // Asynchronous network call to fetch release data.
    URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
      guard let data = data else {
        self?.updateUI {
          printOS("Fetch failed: \(error?.localizedDescription ?? "Unknown error")")
        }
        return
      }

      do {
        // Decoding the JSON response into the Release model.
        let decodedResponse = try JSONDecoder().decode(Release.self, from: data)
        self?.updateUI {
          appState.releases = [decodedResponse]
          appState.changelogText = decodedResponse.modifiedBody
          // If not releaseOnly, proceed to check for an update.
          if !releaseOnly {
            self?.checkForUpdate(appState: appState, manual: manual)
          }
        }
      } catch {
        self?.updateUI { printOS("JSON decoding error: \(error.localizedDescription)") }
      }
    }.resume()
  }

  // Dismisses the update window and updates the app state.
  func dismissUpdateWindow(appState: AppState) {
    updateUI {
      appState.updateAvailable = false
      NewWin.close()  // Closes the update notification window.
    }
  }

  // Checks if the fetched release is newer than the current version and updates the app state.
  func checkForUpdate(appState: AppState, manual: Bool) {
    guard let latestRelease = appState.releases.first,
      let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
        as? String
    else {
      if manual {
        updateUI { NewWin.show(appState: appState, width: 500, height: 300, newWin: .no_update) }
      }
      return
    }

    // Compares the latest release tag with the current version to determine if an update is needed.
    let updateIsNeeded =
      latestRelease.tagName.compare(currentVersion, options: .numeric) == .orderedDescending

    updateUI {
      appState.updateAvailable = updateIsNeeded
      // If manual check and no update is needed, show the no update window.
      if manual && !updateIsNeeded {
        NewWin.show(appState: appState, width: 400, height: 200, newWin: .no_update)
      }
    }
  }

  // Downloads the update from GitHub and prepares it for installation.
  func downloadUpdate(appState: AppState) {
    guard let latestRelease = appState.releases.first,
      let asset = latestRelease.assets.first,
      let url = URL(string: asset.browserDownloadURL)
    else {
      updateUI { appState.progressBar = ("", 0) }
      return
    }

    let fileManager = FileManager.default
    let destinationURL = fileManager.temporaryDirectory.appendingPathComponent(asset.name)

    // If the update file already exists, proceed to unzip and replace the app.
    if fileManager.fileExists(atPath: destinationURL.path) {
      updateUI {
        appState.progressBar = ("", 1.0)
        self.UnzipAndReplace(downloadedFileURL: destinationURL.path, appState: appState)
      }
      return
    }

    // Start the download and update the progress bar.
    updateUI { appState.progressBar = ("", 0.1) }

    // Download task for the update file.
    let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
    URLSession.shared.downloadTask(with: request) { [weak self] localURL, _, error in
      guard let localURL = localURL else {
        self?.updateUI {
          printOS("Download error: \(error?.localizedDescription ?? "Unknown error")")
        }
        return
      }

      do {
        // Move the downloaded file to the temporary directory.
        if fileManager.fileExists(atPath: destinationURL.path) {
          try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: localURL, to: destinationURL)
        self?.updateUI {
          appState.progressBar = ("", 0.5)
          self?.UnzipAndReplace(downloadedFileURL: destinationURL.path, appState: appState)
        }
      } catch {
        self?.updateUI { printOS("File operation error: \(error.localizedDescription)") }
      }
    }.resume()
  }

  // Unzips the downloaded update and replaces the current app with the new version.
  func UnzipAndReplace(downloadedFileURL fileURL: String, appState: AppState) {
    let appDirectory = Bundle.main.bundleURL.deletingLastPathComponent()
    let appBundle = Bundle.main.bundleURL
    let fileManager = FileManager.default

    do {
      // Unzip the downloaded file and replace the existing app.
      updateUI { appState.progressBar = ("", 0.5) }
      try fileManager.removeItem(at: appBundle)

      updateUI { appState.progressBar = ("", 0.6) }
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
      process.arguments = ["-xk", fileURL, appDirectory.path]

      // Run the unzip process.
      try process.run()
      process.waitUntilExit()

      updateUI {
        appState.progressBar = ("", 0.8)
        try? fileManager.removeItem(atPath: fileURL)  // Clean up the zip file after extraction.
        appState.progressBar = ("", 1.0)
        appState.updateAvailable = false  // Update the state to reflect that the update has been applied.
      }
    } catch {
      updateUI { printOS("Error updating the app: \(error)") }
    }
  }

  // Updates the UI on the main thread.
  private func updateUI(_ action: @escaping () -> Void) {
    DispatchQueue.main.async(execute: action)
  }
}
