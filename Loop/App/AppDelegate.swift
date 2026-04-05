//
//  AppDelegate.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-05.
//

import Defaults
import Scribe
import SwiftUI
import UserNotifications

@Loggable
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let loopCommandHandler = LoopCommandHandler()
    private lazy var loopSocketManager = LoopSocketManager(handler: loopCommandHandler)
    private var pendingSettingsWindowOpen: Task<(), Never>?
    private var shutdownTask: Task<(), Never>?

    private var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return
            event.eventID == kAEOpenApplication &&
            event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func applicationDidFinishLaunching(_: Notification) {
        configureLogging()

        // Check for and terminate other running Loop instances to prevent accessibility conflicts
        terminateOtherLoopInstances()

        Task {
            await Defaults.iCloud.waitForSyncCompletion()
        }

        // Normal user-facing launches should open Settings, but URL-driven launches need a chance
        // to cancel that presentation when their URL event arrives immediately after startup.
        if !launchedAsLoginItem, !Defaults[.startHidden] {
            scheduleSettingsWindowOpen()
        } else {
            SettingsWindowManager.shared.close()
        }

        DataPatcher.run()
        IconManager.refreshCurrentAppIcon()
        LaunchAtLoginManager.shared.start()
        LoopManager.shared.start()
        WindowDragManager.shared.addObservers()
        StashManager.shared.start()

        Task {
            // Wait to let the app settle and to prevent overwhelming the user
            try? await Task.sleep(for: .seconds(5))

            await Updater.shared.fetchLatestInfo()
            await Updater.shared.showUpdateWindowIfEligible()
        }

        UNUserNotificationCenter.current().delegate = self
        AppDelegate.requestNotificationAuthorization()

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            AccessibilityManager.requestAccess()
        }

        // Register for URL handling
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        // Start the Unix socket listener for loop-cli
        loopSocketManager.start()
    }

    /// Terminates any other running instances of Loop to prevent accessibility permission conflicts.
    private func terminateOtherLoopInstances() {
        let currentProcessId = ProcessInfo.processInfo.processIdentifier
        let bundleId = Bundle.main.bundleIdentifier ?? "com.MrKai77.Loop"

        let runningApps = NSWorkspace.shared.runningApplications
        let otherLoopInstances = runningApps.filter {
            $0.bundleIdentifier == bundleId && $0.processIdentifier != currentProcessId
        }

        guard !otherLoopInstances.isEmpty else {
            log.info("No other Loop instances found")
            return
        }

        log.info("Found \(otherLoopInstances.count) other Loop instance(s), terminating them to prevent accessibility conflicts. TCC operations will be delayed.")

        for instance in otherLoopInstances {
            log.info("Terminating Loop instance (PID: \(instance.processIdentifier))")
            instance.terminate()

            // If the instance doesn't terminate within 2 seconds, force terminate
            Task {
                try? await Task.sleep(for: .seconds(2))

                if instance.isTerminated == false {
                    log.warn("Force terminating Loop instance (PID: \(instance.processIdentifier))")
                    instance.forceTerminate()
                }
            }
        }

        // Give the other instances time to terminate cleanly
        Thread.sleep(forTimeInterval: 1.0)
    }

    /// Applies baseline logging configuration for Scribe.
    private func configureLogging() {
        LogManager.shared.configuration.includeFileAndLineNumber = false
    }

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            log.info("Failed to get URL from event")
            return
        }

        processIncomingURL(url, replyEvent: replyEvent)
    }

    func applicationShouldOpenUntitledFile(_: NSApplication) -> Bool {
        !launchedAsLoginItem && !Defaults[.startHidden]
    }

    func applicationOpenUntitledFile(_: NSApplication) -> Bool {
        cancelPendingSettingsWindowOpen()
        SettingsWindowManager.shared.show()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        SettingsWindowManager.shared.close()
        return false
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard !hasVisibleWindows else {
            return false
        }

        scheduleSettingsWindowOpen()
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if shutdownTask != nil {
            return .terminateLater
        }

        shutdownTask = Task { @MainActor in
            loopSocketManager.stop()
            await StashManager.shared.shutdown()
            self.shutdownTask = nil
            sender.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }

    func application(_: NSApplication, open urls: [URL]) {
        for url in urls {
            processIncomingURL(url)
        }
    }

    private func processIncomingURL(_ url: URL, replyEvent: NSAppleEventDescriptor? = nil) {
        cancelPendingSettingsWindowOpen()
        log.info("Received URL: \(url)")

        let result = loopCommandHandler.handle(url)
        log.info("Response: \(result.jsonResponse)")

        replyEvent?.setDescriptor(
            NSAppleEventDescriptor(string: result.jsonResponse),
            forKeyword: keyDirectObject
        )

        Task { @MainActor in
            result.presentIfNeeded()
        }
    }

    private func scheduleSettingsWindowOpen() {
        guard !launchedAsLoginItem, !Defaults[.startHidden] else {
            return
        }

        cancelPendingSettingsWindowOpen()

        pendingSettingsWindowOpen = Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled else {
                return
            }

            self?.pendingSettingsWindowOpen = nil
            SettingsWindowManager.shared.show()
        }
    }

    private func cancelPendingSettingsWindowOpen() {
        pendingSettingsWindowOpen?.cancel()
        pendingSettingsWindowOpen = nil
    }
}
