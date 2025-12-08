//
//  AppDelegate.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-05.
//

import Defaults
import OSLog
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let urlCommandHandler = URLCommandHandler()
    static let logger = Logger(category: "AppDelegate")

    private var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return
            event.eventID == kAEOpenApplication &&
            event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func applicationDidFinishLaunching(_: Notification) {
        Task {
            await Defaults.iCloud.waitForSyncCompletion()
        }

        if !launchedAsLoginItem {
            SettingsWindowManager.shared.show()
        } else {
            // Closing also hides the dock icon if needed.
            SettingsWindowManager.shared.close()
        }

        DataPatcher.run()
        IconManager.refreshCurrentAppIcon()
        LoopManager.shared.start()
        WindowDragManager.shared.addObservers()
        StashManager.shared.start()

        Task {
            // Wait to let the app settle and to prevent overwhelming the user
            try? await Task.sleep(for: .seconds(5))

            await Updater.shared.fetchLatestInfo()
            if Updater.shared.updateState == .available {
                await Updater.shared.showUpdateWindow()
            }
        }

        UNUserNotificationCenter.current().delegate = self
        AppDelegate.requestNotificationAuthorization()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent _: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            Self.logger.info("Failed to get URL from event")
            return
        }
        Self.logger.info("Received URL: \(url)")
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

    func applicationWillTerminate(_: Notification) {
        StashManager.shared.onApplicationWillTerminate()
    }

    static func relaunch(after seconds: TimeInterval = 0.5) -> Never {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep \(seconds); open \"\(Bundle.main.bundlePath)\""]
        task.launch()
        NSApp.terminate(nil)
        exit(0)
    }

    func application(_: NSApplication, open urls: [URL]) {
        for url in urls {
            urlCommandHandler.handle(url)
        }
    }
}
