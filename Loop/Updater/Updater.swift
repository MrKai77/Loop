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

@Loggable
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    @Published private(set) var updateState: UpdateAvailability = .unavailable {
        didSet { updateStateChanged() }
    }

    @Published private(set) var installState: InstallState = .ready
    @Published private(set) var progressBar: Double = 0
    @Published private(set) var updatesEnabled: Bool = Updater.checkIfUpdatesEnabled()
    @Published private(set) var changelog: [(title: String, body: [ChangelogNote])] = .init()
    @Published var expandedChangelogSections: Set<String> = [] // By title

    private(set) var shouldAutoPresentUpdateWindow: Bool = false
    private var windowController: NSWindowController?
    private var includeDevelopmentVersions: Bool { Defaults[.includeDevelopmentVersions] }
    private var automaticallyUpdate: Bool { Defaults[.automaticallyUpdate] }

    private var updateFetcherTask: Task<(), Never>?
    private var updateCheckerTask: Task<(), Never>?
    private var autoPresentUpdateWindowTask: Task<(), Never>?
    private var includeDevelopmentVersionsObserver: Task<(), Never>?
    private var updatesEnabledObserver: Task<(), Never>?
    private let updateChecker: UpdateChecker
    private let downloader: UpdateDownloader
    private let installer: UpdateInstaller

    @Published private(set) var updateManifest: UpdateManifest?
    @Published private(set) var downloadProgress: UpdateProgress?

    private init() {
        // Initialize new updater system components
        self.updateChecker = UpdateChecker()
        self.downloader = UpdateDownloader()
        self.installer = UpdateInstaller()

        // Initialize optional properties to nil - will be set up after init
        self.updateCheckerTask = nil
        self.includeDevelopmentVersionsObserver = nil
        self.updatesEnabledObserver = nil

        // Set up observers and tasks after initialization is complete
        Task {
            setupObserversAndTasks()
        }
    }

    private func setupObserversAndTasks() {
        // Set up observers and tasks now that self is fully initialized
        let updatesEnabled = Self.checkIfUpdatesEnabled()
        if updatesEnabled {
            updateCheckerTask = makeUpdateCheckerTask()
            includeDevelopmentVersionsObserver = makeIncludeDevelopmentVersionsObserver()
        }

        updatesEnabledObserver = makeUpdatesEnabledObserver()
    }

    private static func checkIfUpdatesEnabled() -> Bool {
        if let env = ProcessInfo.processInfo.environment["LOOP_SKIP_UPDATE_CHECK"],
           env == "1" || env.lowercased() == "true" {
            return false
        }
        return Defaults[.updatesEnabled]
    }

    private func updateStateChanged() {
        autoPresentUpdateWindowTask?.cancel()
        autoPresentUpdateWindowTask = nil

        if updateState == .available {
            // If automatic updates are enabled, never auto-present the update window
            if automaticallyUpdate {
                // Only install if Loop is not in use
                if !NSApp.isActive, NSApp.windows.allSatisfy({ !$0.isVisible }) {
                    log.info("Automatic updates enabled, installing update...")
                    Task {
                        try await installUpdate()
                    }
                }

                log.info("Automatic updates enabled, but Loop is active. Skipping installation.")
                return
            }

            shouldAutoPresentUpdateWindow = true

            /// If the updater has requested that the update window be presented for over 6 hours, automatically present it.
            autoPresentUpdateWindowTask = Task {
                log.info("Will automatically present update window in 6 hours if there is no activity")

                try? await Task.sleep(for: .seconds(21600))

                if !Task.isCancelled, shouldAutoPresentUpdateWindow {
                    await showUpdateWindowIfEligible()
                }

                autoPresentUpdateWindowTask = nil
            }
        } else {
            shouldAutoPresentUpdateWindow = false
        }
    }

    private func makeUpdateCheckerTask() -> Task<(), Never>? {
        Task {
            while !Task.isCancelled {
                // 6 hours
                try? await Task.sleep(for: .seconds(21600))

                await self.fetchLatestInfo()
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

                updatesEnabled = Updater.checkIfUpdatesEnabled()

                log.info("Updates enabled status changed to: \(updatesEnabled)")

                if updatesEnabled {
                    self.updateCheckerTask = makeUpdateCheckerTask()
                    self.includeDevelopmentVersionsObserver = makeIncludeDevelopmentVersionsObserver()
                } else {
                    self.updateCheckerTask?.cancel()
                    self.includeDevelopmentVersionsObserver?.cancel()
                    self.updateCheckerTask = nil
                    self.includeDevelopmentVersionsObserver = nil

                    updateManifest = nil
                    updateState = .unavailable
                    progressBar = 0
                    downloadProgress = nil
                }
            }
        }
    }

    func dismissWindow() {
        windowController?.close()
        windowController = nil

        // Clear update state when window is dismissed
        updateManifest = nil
        progressBar = 0
        downloadProgress = nil
        installState = .ready
        shouldAutoPresentUpdateWindow = false
    }

    // Pulls the latest release information from GitHub and updates the app state accordingly.
    func fetchLatestInfo(force: Bool = false) async {
        // Don't run update checks while actively downloading
        if downloader.isDownloading == true {
            return
        }

        if let updateFetcherTask {
            await updateFetcherTask.value // If already fetching, wait for it to finish
            return
        }

        updateFetcherTask = Task {
            defer { updateFetcherTask = nil }

            // Don't clear update state if window is currently showing (user is interacting)
            if windowController?.window?.isVisible != true {
                updateManifest = nil
                progressBar = 0
                downloadProgress = nil
            }

            // Early return if updates are disabled and not forcing
            guard updatesEnabled || force else {
                updateState = .unavailable
                return
            }

            log.info("Fetching latest release info...")

            do {
                // Use GitHub releases API
                let channel: UpdateChannel = includeDevelopmentVersions ? .development : .stable

                let currentVersion = Bundle.main.appVersion?.filter(\.isASCII)
                    .trimmingCharacters(in: .whitespaces) ?? "0.0.0"
                let currentBuild = Bundle.main.appBuild ?? 0

                if let manifest = try await updateChecker.checkForUpdate(
                    bundleId: Bundle.main.bundleIdentifier ?? "com.MrKai77.Loop",
                    currentVersion: currentVersion,
                    currentBuild: currentBuild,
                    channel: channel
                ) {
                    updateManifest = manifest
                    updateState = .available
                    processChangelog(manifest.releaseNotes.body)

                    log.notice("Update available: \(manifest.version) build \(manifest.buildNumber)")
                } else {
                    updateState = .unavailable

                    log.info("No updates available")
                }
            } catch {
                if case .incompatibleSystem? = error as? UpdateError {
                    updateState = .osNotSupported
                } else {
                    updateState = .unavailable
                }

                log.error("Error fetching release info: \(error.localizedDescription)")
            }
        }

        await updateFetcherTask?.value
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

        if let firstSection = changelog.first {
            expandedChangelogSections = [firstSection.title]
        }
    }

    func showUpdateWindowIfEligible() async {
        shouldAutoPresentUpdateWindow = false
        guard updateState == .available else { return }

        if windowController?.window == nil {
            windowController = .init(window: LuminareTrafficLightedWindow { UpdateView() })
        }
        windowController?.window?.makeKeyAndOrderFront(self)
        windowController?.window?.orderFrontRegardless()

        log.ui("Update window shown")
    }

    // Downloads the update from GitHub and installs it
    func installUpdate() async throws {
        guard let manifest = updateManifest else {
            progressBar = 0
            return
        }

        installState = .installing

        log.info("Installing update: \(manifest.version)")

        do {
            let downloadedFileURL = try await downloader.downloadUpdate(manifest: manifest) { [weak self] progress in
                self?.progressBar = progress.percentage
                self?.downloadProgress = progress
            }

            try await installer.installUpdate(from: downloadedFileURL, manifest: manifest)

            progressBar = 1.0
            updateState = .unavailable

            // Brief delay before showing restart button
            try? await Task.sleep(for: .seconds(1))

            installState = .readyToRestart

            log.success("Update installed successfully")
        } catch {
            log.error("Update installation failed: \(error)")
            progressBar = 0
            installState = .failed(error)
            throw error
        }
    }

    func relaunchAfterUpdate() {
        Task {
            await installer.restartApplication()
        }
    }
}
