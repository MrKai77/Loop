//
//  LoopApp.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import SwiftUI
import Defaults
import ServiceManagement
import MenuBarExtraAccess

@main
struct LoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let aboutViewController = AboutViewController()
    @State var isMenubarItemPresented: Bool = false

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

        MenuBarExtra("Loop", image: "") {
            #if DEBUG
            Text("DEV BUILD: \(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
            #endif

            Button("Settings") {
                NSApp.openSettings()
                NSApp.setActivationPolicy(.regular)
                if #available(macOS 14.0, *) {
                    NSApp.activate()
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                }
                for window in NSApp.windows where window.title != "About \(Bundle.main.appName)" {
                    window.orderFrontRegardless()
                }
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("About \(Bundle.main.appName)") {
                aboutViewController.showAboutWindow()
                NSApp.setActivationPolicy(.regular)
                if #available(macOS 14.0, *) {
                    NSApp.activate()
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                }
                for window in NSApp.windows where window.title == "About \(Bundle.main.appName)" {
                    window.orderFrontRegardless()
                }
            }
            .keyboardShortcut("i", modifiers: .command)

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)
        .menuBarExtraAccess(isPresented: $isMenubarItemPresented) { statusItem in
            statusItem.length = 22

            guard let button = statusItem.button else { return }

            let view = NSHostingView(rootView: MenubarIconView())
            view.frame.size = NSSize(width: 22, height: 22)
            button.addSubview(view)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    private let accessibilityAccessManager = AccessibilityAccessManager()
    private let iconManager = IconManager()
    private let loopManager = LoopManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
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
