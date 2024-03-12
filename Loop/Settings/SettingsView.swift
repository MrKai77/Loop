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
    private var appListManager = AppListManager()
    
    var body: some View {
        TabView(selection: $currentSettingsTab) {
            GeneralSettingsView()
                .tag(1)
                .tabItem {
                    Image(systemName: "gear")
                    Text("General")
                }
                .frame(width: 450)

            RadialMenuSettingsView()
                .tag(2)
                .tabItem {
                    Image(.loop)
                    Text("Radial Menu")
                }
                .frame(width: 450)

            PreviewSettingsView()
                .tag(3)
                .tabItem {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Preview")
                }
                .frame(width: 450)

            KeybindingsSettingsView()
                .tag(4)
                .tabItem {
                    Image(systemName: "keyboard")
                    Text("Keybindings")
                }
                .frame(width: 500)
                .frame(minHeight: 500, maxHeight: 680)

            BlackListSettingsView()
                .tag(5)
                .tabItem {
                    Image(systemName: "xmark.rectangle")
                    Text("Black list")
                }
                .environmentObject(appListManager)
                .frame(width: 500)
                .frame(minHeight: 500, maxHeight: 680)

            MoreSettingsView()
                .tag(6)
                .tabItem {
                    Image(systemName: "ellipsis.circle")
                    Text("More")
                }
                .environmentObject(updater)
                .frame(width: 450)
        }
        .fixedSize(horizontal: true, vertical: true)
    }
}
