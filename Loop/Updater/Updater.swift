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
final class Updater: ObservableObject {
    static let shared = Updater()

    @Published private(set) var updateState: UpdateAvailability = .unavailable {
        didSet { updateStateChanged() }
    }

    @Published private(set) var targetRelease: Release?
    @Published private(set) var progressBar: Double = 0
    @Published private(set) var updatesEnabled: Bool = Updater.checkIfUpdatesEnabled()
    @Published private(set) var changelog: [(title: String, body: [ChangelogNote])] = .init()
    @Published var expandedChangelogSections: Set<String> = [] // By title

    private(set) var shouldAutoPresentUpdateWindow: Bool = false
    private var windowController: NSWindowController?
    private var includeDevelopmentVersions: Bool { Defaults[.includeDevelopmentVersions] }

    private var updateFetcherTask: Task<(), Never>?
    private var updateCheckerTask: Task<(), Never>?
    private var autoPresentUpdateWindowTask: Task<(), Never>?
    private var includeDevelopmentVersionsObserver: Task<(), Never>?
    private var updatesEnabledObserver: Task<(), Never>?
    private let config: UpdaterConfig = UpdaterConfigProvider.shared
    private let updateChecker: UpdateChecker
    private var downloader: Downloader?
    private let installer: UpdateInstaller

    @Published private(set) var updateManifest: UpdateManifest?
    @Published private(set) var downloadProgress: UpdateProgress?

    struct ChangelogNote: Identifiable, Equatable {
        var id: UUID = .init()
        var emoji: String
        var text: String
        var user: String?
        var reference: Int?

        static func == (lhs: ChangelogNote, rhs: ChangelogNote) -> Bool {
            lhs.emoji == rhs.emoji &&
                lhs.text == rhs.text &&
                lhs.user == rhs.user &&
                lhs.reference == rhs.reference
        }
    }

    enum UpdateAvailability {
        case available
        case unavailable
        case osNotSupported

        var text: String {
            switch self {
            case .unavailable:
                String(localized: "Check for updates…")
            case .available:
                String(localized: "Update…")
            case .osNotSupported:
                String(localized: "This macOS version is no longer supported.")
            }
        }
    }

    private init() {
        // Initialize new updater system components
        self.updateChecker = UpdateChecker(config: config)
        self.installer = UpdateInstaller(config: config)
        self.downloader = nil

        // Initialize optional properties to nil - will be set up after init
        self.updateCheckerTask = nil
        self.includeDevelopmentVersionsObserver = nil
        self.updatesEnabledObserver = nil

        // Set up observers and tasks after initialization is complete
        DispatchQueue.main.async { [weak self] in
            self?.setupObserversAndTasks()
        }
    }

    @MainActor private func setupObserversAndTasks() {
        // Initialize downloader on main actor
        downloader = Downloader(config: config)

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

                await MainActor.run {
                    updatesEnabled = Updater.checkIfUpdatesEnabled()
                }

                log.info("Updates enabled status changed to: \(updatesEnabled)")

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
                        updateManifest = nil
                        updateState = .unavailable
                        progressBar = 0
                        downloadProgress = nil
                    }
                }
            }
        }
    }

    @MainActor
    func dismissWindow() {
        windowController?.close()
        windowController = nil

        // Clear update state when window is dismissed
        targetRelease = nil
        updateManifest = nil
        progressBar = 0
        downloadProgress = nil
        shouldAutoPresentUpdateWindow = false
    }

    // Pulls the latest release information from GitHub and updates the app state accordingly.
    func fetchLatestInfo(force: Bool = false) async {
        let isDownloading = await (downloader?.currentDownloadState ?? .idle) == .downloading

        // Don't run update checks while actively downloading
        if isDownloading {
            return
        }

        if let updateFetcherTask {
            await updateFetcherTask.value // If already fetching, wait for it to finish
            return
        }

        updateFetcherTask = Task {
            defer { updateFetcherTask = nil }

            await MainActor.run {
                // Don't clear update state if window is currently showing (user is interacting)
                if windowController?.window?.isVisible != true {
                    targetRelease = nil
                    updateManifest = nil
                    progressBar = 0
                    downloadProgress = nil
                }
            }

            // Early return if updates are disabled and not forcing
            guard updatesEnabled || force else {
                await MainActor.run {
                    updateState = .unavailable
                }
                return
            }

            log.info("Fetching latest release info...")

            do {
                // Use GitHub releases API
                let channel: UpdateChannel = includeDevelopmentVersions ? .beta : .stable
                let currentVersion = Bundle.main.appVersion?.filter(\.isASCII).trimmingCharacters(in: .whitespaces) ?? "0.0.0"

                let currentBuild = Bundle.main.appBuild ?? 0
                if let manifest = try await updateChecker.checkForUpdate(
                    bundleId: Bundle.main.bundleIdentifier ?? "com.MrKai77.Loop",
                    currentVersion: currentVersion,
                    currentBuild: currentBuild,
                    channel: channel,
                    force: force
                ) {
                    await processUpdateManifest(manifest, force: force)
                } else {
                    await MainActor.run {
                        updateState = .unavailable
                    }
                }
            } catch {
                await MainActor.run {
                    updateState = .unavailable
                }
                log.error("Error fetching release info: \(error.localizedDescription)")
            }
        }

        await updateFetcherTask?.value
    }

    private func processUpdateManifest(_ manifest: UpdateManifest, force: Bool = false) async {
        await MainActor.run {
            updateManifest = manifest

            // Convert new manifest to old Release format for UI compatibility
            targetRelease = Release.from(manifest: manifest)

            let currentVersion = Bundle.main.appVersion?.filter(\.isASCII).trimmingCharacters(in: .whitespaces) ?? "0.0.0"
            let currentBuild = Bundle.main.appBuild ?? 0

            // Check version and build numbers
            var newUpdateState: UpdateAvailability = .unavailable

            let versionComparison = manifest.version.compare(currentVersion, options: .numeric)
            if versionComparison == .orderedDescending {
                newUpdateState = .available
            } else if versionComparison == .orderedSame {
                // Same version, check build numbers
                if manifest.buildNumber > currentBuild {
                    newUpdateState = .available
                }
            }

            // For forced checks, show update info even if not newer
            if force, newUpdateState == .unavailable {
                log.info("Forced update check - showing update info for: \(manifest.version) (\(manifest.buildNumber))")
                newUpdateState = .available // Show update UI for forced checks
            }

            updateState = newUpdateState

            if newUpdateState == .available {
                log.notice("Update available: \(manifest.version) build \(manifest.buildNumber)")
                processChangelog(manifest.releaseNotes.body)
            } else {
                log.info("No update available.")
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

        if let firstSection = changelog.first {
            expandedChangelogSections = [firstSection.title]
        }
    }

    @MainActor
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
    func installUpdate() async {
        guard let manifest = updateManifest else {
            await MainActor.run {
                self.progressBar = 0
            }
            return
        }

        log.info("Installing update: \(manifest.version)")

        do {
            // Use new installer system
            let downloadURL = try await downloadUpdate(manifest)
            try await installer.installUpdate(from: downloadURL, manifest: manifest)

            await MainActor.run {
                self.progressBar = 1.0
                self.updateState = .unavailable
                self.updateManifest = nil
                self.downloader = nil // Reset downloader for next installation attempt
            }

            log.success("Update installed successfully")

        } catch {
            log.error("Update installation failed: \(error)")
            await MainActor.run {
                self.progressBar = 0
                self.downloader = nil // Reset downloader on failure
            }
        }
    }

    private func downloadUpdate(_ manifest: UpdateManifest) async throws -> URL {
        guard let downloader else {
            throw UpdateError.network(NSError(domain: "Updater", code: -1, userInfo: [NSLocalizedDescriptionKey: "Downloader not initialized"]))
        }

        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                downloader.downloadUpdate(manifest: manifest, progress: { progress in
                    Task { @MainActor in
                        self.progressBar = progress.percentage
                        self.downloadProgress = progress
                    }
                }) { result in
                    switch result {
                    case let .success(url):
                        continuation.resume(returning: url)
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}
