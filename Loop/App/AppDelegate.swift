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
    private let urlCommandHandler = URLCommandHandler()
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

        // Show settings window only if not launched as login item AND startHidden is disabled
        if !launchedAsLoginItem, !Defaults[.startHidden] {
            SettingsWindowManager.shared.show()
        } else {
            // Closing also hides the dock icon if needed.
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

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent _: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            log.info("Failed to get URL from event")
            return
        }

        log.info("Received URL: \(url)")
        urlCommandHandler.handle(url)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        SettingsWindowManager.shared.close()
        return false
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        SettingsWindowManager.shared.show()
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if shutdownTask != nil {
            return .terminateLater
        }

        // LoopManager and WindowDragManager are explicitly shut down so that their
        // event monitors are stopped immediately (in case they are active)
        LoopManager.shared.shutdown()
        WindowDragManager.shared.shutdown()

        shutdownTask = Task { @MainActor in
            let didFinishStashShutdown = await runStashShutdownWithTimeout(.seconds(3))
            if !didFinishStashShutdown {
                log.warn("Timed out while restoring stashed windows during termination. Continuing shutdown.")
            }

            self.shutdownTask = nil
            sender.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }

    func application(_: NSApplication, open urls: [URL]) {
        for url in urls {
            urlCommandHandler.handle(url)
        }
    }

    private func runStashShutdownWithTimeout(_ duration: Duration) async -> Bool {
        await withCheckedContinuation { continuation in
            let reply = OneShotContinuation(continuation)

            let shutdownTask = Task { @MainActor in
                await StashManager.shared.shutdown()
                reply.resume(returning: true)
            }

            Task {
                try? await Task.sleep(for: duration)
                shutdownTask.cancel()
                reply.resume(returning: false)
            }
        }
    }
}

private final class OneShotContinuation<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<T, Never>

    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    func resume(returning result: T) {
        lock.lock()
        defer { lock.unlock() }

        guard !didResume else { return }
        didResume = true
        continuation.resume(returning: result)
    }
}
