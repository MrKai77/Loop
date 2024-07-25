//
//  AppDelegate.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-05.
//

import Defaults
import SwiftUI
import UserNotifications
import DynamicNotchKit

class AppDelegate: NSObject, NSApplicationDelegate {
    static let loopManager = LoopManager()
    static let windowDragManager = WindowDragManager()
    static let updater = Updater()
    static var isActive: Bool = false
    var dynamicNotch: DynamicNotch?

    private var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return
            event.eventID == kAEOpenApplication &&
            event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func applicationDidFinishLaunching(_: Notification) {
        NSApplication.shared.delegate = self
        Task {
            await Defaults.iCloud.waitForSyncCompletion()
        }

        // Check & ask for accessibility access
        AccessibilityManager.requestAccess()
        UNUserNotificationCenter.current().delegate = self

        AppDelegate.requestNotificationAuthorization()

        IconManager.refreshCurrentAppIcon()
        AppDelegate.loopManager.start()
        AppDelegate.windowDragManager.addObservers()

        if !launchedAsLoginItem {
            LuminareManager.open()
        } else {
            // Dock icon is usually handled by LuminareManager, but in this case, it is manually set
            if !Defaults[.showDockIcon] {
                NSApp.setActivationPolicy(.accessory)
            }
        }
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

    static func relaunch(after seconds: TimeInterval = 0.5) -> Never {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep \(seconds); open \"\(Bundle.main.bundlePath)\""]
        task.launch()
        NSApp.terminate(nil)
        exit(0)
    }
    
    func showPopup(content: any View, seconds: Double? = 2) {
        if let dynamicNotch = self.dynamicNotch,
           dynamicNotch.isVisible {
            dynamicNotch.hide()
        }
        
        dynamicNotch = DynamicNotch(content: content)
        
        if let seconds = seconds {
            dynamicNotch?.show(for: seconds)
        } else {
            dynamicNotch?.show()
        }
    }
    
    func hidePopup() {
        if let dynamicNotch = self.dynamicNotch,
           dynamicNotch.isVisible {
            dynamicNotch.hide()
        }
    }
}
