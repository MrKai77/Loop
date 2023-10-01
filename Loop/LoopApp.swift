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
import Settings

@main
struct LoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let aboutViewController = AboutViewController()
    @State var isMenubarItemPresented: Bool = false

    var body: some Scene {
        MenuBarExtra("Loop", image: "") {
            #if DEBUG
            MenuBarHeaderText("DEV BUILD: \(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
            #endif

            Menu("Resize…") {
                MenuBarHeaderText("General")
                ForEach(WindowDirection.general) { MenuBarResizeButton($0) }
                Divider()

                MenuBarHeaderText("Halves")
                ForEach(WindowDirection.halves) { MenuBarResizeButton($0) }
                Divider()

                MenuBarHeaderText("Quarters")
                ForEach(WindowDirection.quarters) { MenuBarResizeButton($0) }
                Divider()

                MenuBarHeaderText("Horizontal Thirds")
                ForEach(WindowDirection.horizontalThirds) { MenuBarResizeButton($0) }
                Divider()

                MenuBarHeaderText("Vertical Thirds")
                ForEach(WindowDirection.verticalThirds) { MenuBarResizeButton($0) }
            }

            Button("Settings") {
                NSApp.setActivationPolicy(.regular)
                appDelegate.openSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("About \(Bundle.main.appName)") {
                NSApp.setActivationPolicy(.regular)
                aboutViewController.open()
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

            let view = NSHostingView(rootView: MenuBarIconView())
            view.frame.size = NSSize(width: 22, height: 22)
            button.addSubview(view)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    private let iconManager = IconManager()
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
                toolbarIcon: NSImage(resource: .radialMenu)
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

        iconManager.refreshCurrentAppIcon()
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
