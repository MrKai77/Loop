//
//  LoopApp.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import SwiftUI
import Defaults
import ServiceManagement
import AppMover

@main
struct LoopApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let aboutViewController = AboutViewController()

    var body: some Scene {
        Settings {
            SettingsView()
        }
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

        MenuBarExtra("Loop", image: "menubarIcon") {
            #if DEBUG
            Text("DEV BUILD: \(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
            #endif

            if #available(macOS 14, *) {
                SettingsLink()
                    .keyboardShortcut(",", modifiers: .command)
            } else {
                Button("Settings") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            Button("About \(Bundle.main.appName)") {
                aboutViewController.showAboutWindow()
            }
            .keyboardShortcut("i", modifiers: .command)

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    private let accessibilityAccessManager = AccessibilityAccessManager()
    private let iconManager = IconManager()
    private let loopManager = LoopManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try AppMover.moveApp()
        } catch {
            print("Moving app failed: \(error)")
        }

        // Check accessibility access, then if access is not granted,
        // show a more informative alert asking for accessibility access
        if !accessibilityAccessManager.getStatus() {
            accessibilityAccessManager.requestAccess()
        }
        iconManager.restoreCurrentAppIcon()

        loopManager.startObservingKeys()

//        NSApp.setActivationPolicy(.accessory)
    }
}
