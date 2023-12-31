//
//  AppDelegate.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-05.
//

import SwiftUI
import Defaults

class AppDelegate: NSObject, NSApplicationDelegate {

    private let loopManager = LoopManager()
    private let windowDragManager = WindowDragManager()
    private var canOpenSettings = false

    private var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return
            event.eventID == kAEOpenApplication &&
            event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Check & ask for accessibility access
        PermissionsManager.Accessibility.requestAccess()

        IconManager.refreshCurrentAppIcon()
        loopManager.startObservingKeys()
        windowDragManager.addObservers()

        if self.launchedAsLoginItem {
            // Ensures Loop's settings window isn't opened upon login
            // (cause MANY system processes are already currently initializing at this point)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.canOpenSettings = true
            }
        } else {
            self.canOpenSettings = true
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        NSApp.setActivationPolicy(.accessory)
        for window in NSApp.windows where window.delegate != nil {
            window.delegate = nil
        }
        return false
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        guard canOpenSettings else { return }
        self.openSettings()
    }

    // Mostly taken from https://github.com/Wouter01/SwiftUI-WindowManagement
    func openSettings() {
        // Settings window is already open
        guard !NSApp.windows.contains(where: { $0.toolbar?.items != nil }) else {
            NSApp.windows.first(where: { $0.toolbar?.items != nil })?.orderFrontRegardless()
            return
        }

        let eventSource = CGEventSource(stateID: .hidSystemState)
        let keyCommand = CGEvent(keyboardEventSource: eventSource, virtualKey: 0x2B, keyDown: true)
        guard let keyCommand else { return }

        keyCommand.flags = .maskCommand
        let event = NSEvent(cgEvent: keyCommand)
        guard let event else { return }

        NSApp.sendEvent(event)

        for window in NSApp.windows where window.toolbar?.items != nil {
            window.orderFrontRegardless()
            window.center()
        }
    }
}
