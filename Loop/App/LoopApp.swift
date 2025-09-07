//
//  LoopApp.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import Defaults
import SwiftUI

@main
struct LoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State var isMenubarItemPresented: Bool = false
    @Default(.hideMenuBarIcon) var hideMenuBarIcon

    var body: some Scene {
        MenuBarExtra(Bundle.main.appName, image: "menubarIcon", isInserted: Binding.constant(!hideMenuBarIcon)) {
            #if DEBUG
                let text = "DEV BUILD: \(Bundle.main.appVersion ?? "Unknown") (\(Bundle.main.appBuild ?? 0))"
                Text(text)
                    .font(.system(size: 11, weight: .semibold))
            #endif

            Button {
                if let url = URL(string: "https://github.com/sponsors/MrKai77") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "heart")
                    Text("Donate…")
                }
            }

            Button("Settings…") {
                LuminareManager.shared.showWindow(self)
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)
    }
}
