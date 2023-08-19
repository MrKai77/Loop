//
//  LoopApp.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import SwiftUI
import Defaults
import ServiceManagement
import WindowManagement

@main
struct LoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let aboutViewController = AboutViewController()

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .registerSettingsWindow()
        .enableOpenWindow()
        .commands {
            CommandGroup(replacing: CommandGroupPlacement.appInfo) {
                Button("About \(Bundle.main.appName)") { aboutViewController.showAboutWindow() }
                    .keyboardShortcut("i")
            }
            CommandGroup(replacing: CommandGroupPlacement.appTermination) {
                Button("Quit \(Bundle.main.appName)") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    private let accessibilityAccessManager = AccessibilityAccessManager()
    private let statusItemController = StatusItemController()
    private let iconManager = IconManager()
    private let loopManager = LoopManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController.show()
        NSApp.setActivationPolicy(.accessory)

        // Check accessibility access, then if access is not granted,
        // show a more informative alert asking for accessibility access
        if !accessibilityAccessManager.getStatus() {
            accessibilityAccessManager.requestAccess()
        }
        iconManager.restoreCurrentAppIcon()

        loopManager.startObservingKeys()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        NSApp.setActivationPolicy(.accessory)
        return false
    }
}
