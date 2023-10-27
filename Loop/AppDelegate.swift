//
//  AppDelegate.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-05.
//

import SwiftUI
import Settings
import Defaults

class AppDelegate: NSObject, NSApplicationDelegate {

    private let loopManager = LoopManager()

    private let updater = SoftwareUpdater()
    private lazy var settingsWindowController = SettingsWindowController(
        panes: [
            Settings.Pane(
                identifier: .general,
                title: "General",
                toolbarIcon: NSImage(
                    systemSymbolName: "gear",
                    accessibilityDescription: nil
                )!
            ) {
                GeneralSettingsView()
            },

            Settings.Pane(
                identifier: .radialMenu,
                title: "Radial Menu",
                toolbarIcon: NSImage(named: "loop")!
            ) {
                RadialMenuSettingsView()
            },

            Settings.Pane(
                identifier: .preview,
                title: "Preview",
                toolbarIcon: NSImage(
                    systemSymbolName: "rectangle.portrait.and.arrow.right",
                    accessibilityDescription: nil
                )!
            ) {
                PreviewSettingsView()
            },

            Settings.Pane(
                identifier: .keybindings,
                title: "Keybindings",
                toolbarIcon: NSImage(
                    systemSymbolName: "keyboard",
                    accessibilityDescription: nil
                )!
            ) {
                KeybindingsSettingsView()
            },

            Settings.Pane(
                identifier: .more,
                title: "More",
                toolbarIcon: NSImage(
                    systemSymbolName: "ellipsis.circle",
                    accessibilityDescription: nil
                )!
            ) {
                MoreSettingsView()
                    .environmentObject(updater)
            }
        ]
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Check & ask for accessibility access
        PermissionsManager.Accessibility.requestAccess()

        IconManager.refreshCurrentAppIcon()
        loopManager.startObservingKeys()

        if Defaults[.windowSnapping] {
            SnappingManager.shared.addObservers()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        NSApp.setActivationPolicy(.accessory)
        return false
    }

    func openSettingsWindow() {
        self.settingsWindowController.show()
        self.settingsWindowController.window?.orderFrontRegardless()
    }
}
