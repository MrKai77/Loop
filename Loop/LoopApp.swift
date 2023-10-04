//
//  LoopApp.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import SwiftUI
import MenuBarExtraAccess

@main
struct LoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let aboutViewController = AboutViewController()
    @State var isMenubarItemPresented: Bool = false

    var body: some Scene {
        MenuBarExtra("Loop", image: "") {
            #if DEBUG
            Text("DEV BUILD: \(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
            #endif

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

            let view = NSHostingView(rootView: MenubarIconView())
            view.frame.size = NSSize(width: 22, height: 22)
            button.addSubview(view)
        }
    }
}
