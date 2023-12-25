//
//  SettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-11-30.
//

import SwiftUI
import Sparkle

struct SettingsView: View {
    @State var currentSettingsTab = 1
    private let updater = SoftwareUpdater()

    var body: some View {
        TabView(selection: $currentSettingsTab) {
            GeneralSettingsView()
                .tag(1)
                .tabItem {
                    Image(systemName: "gear")
                    Text("General")
                }

            RadialMenuSettingsView()
                .tag(2)
                .tabItem {
                    Image(.loop)
                    Text("Radial Menu")
                }

            PreviewSettingsView()
                .tag(3)
                .tabItem {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Preview")
                }

            KeybindingsSettingsView()
                .tag(4)
                .tabItem {
                    Image(systemName: "keyboard")
                    Text("Keybindings")
                }

            MoreSettingsView()
                .tag(5)
                .tabItem {
                    Image(systemName: "ellipsis.circle")
                    Text("More")
                }
                .environmentObject(updater)
        }
        .frame(width: 450)
        .fixedSize(horizontal: false, vertical: true)
    }
}
