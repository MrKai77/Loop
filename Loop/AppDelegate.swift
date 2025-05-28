//
//  AppDelegate.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-05.
//

import Defaults
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    static let loopManager = LoopManager()
    static let stashManager = StashManager()
    static let windowDragManager = WindowDragManager()
    static let updater = Updater()
    static var isActive: Bool = false
    static let urlCommandHandler = URLCommandHandler()

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
            LuminareManager.open()
        } else {
            // Dock icon is usually handled by LuminareManager, but in this case, it is manually set
            if !Defaults[.showDockIcon] {
                NSApp.setActivationPolicy(.accessory)
            }
        }

        #if !DEBUG
            IconManager.refreshCurrentAppIcon()
        #endif
        AppDelegate.loopManager.start()
        AppDelegate.windowDragManager.addObservers()
        AppDelegate.stashManager.start()

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
            print("Failed to get URL from event")
            return
        }
        print("Received URL: \(url)")
        AppDelegate.urlCommandHandler.handle(url)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        LuminareManager.fullyClose()
        return false
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        LuminareManager.open()
        return true
    }

    func applicationWillBecomeActive(_: Notification) {
        Notification.Name.activeStateChanged.post(object: true)
        AppDelegate.isActive = true
    }

    func applicationWillResignActive(_: Notification) {
        Notification.Name.activeStateChanged.post(object: false)
        AppDelegate.isActive = false
    }

    func applicationWillTerminate(_: Notification) {
        Self.stashManager.onApplicationWillTerminate()
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
            AppDelegate.urlCommandHandler.handle(url)
        }
    }
}
