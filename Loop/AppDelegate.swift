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
    static let windowDragManager = WindowDragManager()
    static var isActive: Bool = false

    private var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return
            event.eventID == kAEOpenApplication &&
            event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func applicationDidFinishLaunching(_: Notification) {
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
}
