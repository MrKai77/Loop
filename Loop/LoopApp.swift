//
//  LoopApp.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import Defaults
import MenuBarExtraAccess
import SwiftUI

@main
struct LoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State var isMenubarItemPresented: Bool = false
    @Default(.hideMenuBarIcon) var hideMenuBarIcon

    var body: some Scene {
        MenuBarExtra(Bundle.main.appName, image: "empty", isInserted: Binding.constant(!hideMenuBarIcon)) {
            #if DEBUG
                MenuBarHeaderText("DEV BUILD: \(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
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

            Divider()

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

            Button("Settings…") {
                LuminareManager.open()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)
        .menuBarExtraAccess(isPresented: $isMenubarItemPresented) { statusItem in
            guard
                let button = statusItem.button,
                button.subviews.isEmpty
            else {
                return
            }

            let view = NSHostingView(rootView: MenuBarIconView())
            view.frame.size = NSSize(width: 26, height: 22)
            button.addSubview(view)
        }
    }
}
