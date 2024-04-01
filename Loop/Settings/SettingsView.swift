//
//  SettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-11-30.
//

import SwiftUI
import Sparkle

struct SettingsView: View {
    @State var currentSettingsTab = SettingsTab.general
    @StateObject private var updater = SoftwareUpdater()
    private var appListManager = AppListManager()

    var body: some View {
        TabView(selection: $currentSettingsTab) {
            GeneralSettingsView()
                .tag(SettingsTab.general)
                .tabItem {
                    Image(systemName: "gear")
                    Text("General")
                }
                .frame(width: 450)

            RadialMenuSettingsView()
                .tag(SettingsTab.radialMenu)
                .tabItem {
                    Image(.loop)
                    Text("Radial Menu")
                }
                .frame(width: 450)

            PreviewSettingsView()
                .tag(SettingsTab.preview)
                .tabItem {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Preview")
                }
                .frame(width: 450)

            KeybindingsSettingsView()
                .tag(SettingsTab.keybindings)
                .tabItem {
                    Image(systemName: "keyboard")
                    Text("Keybindings")
                }
                .frame(width: 500)
                .frame(minHeight: 500, maxHeight: 680)

            ExcludeListSettingsView()
                .tag(SettingsTab.excludedApps)
                .tabItem {
                    Image(systemName: "xmark.app")
                    Text("Excluded Apps")
                }
                .environmentObject(appListManager)
                .frame(width: 450)
                .frame(maxHeight: 680)

            MoreSettingsView()
                .tag(SettingsTab.more)
                .tabItem {
                    Image(systemName: "ellipsis.circle")
                    Text("More")
                }
                .environmentObject(updater)
                .frame(width: 450)
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    enum SettingsTab: Int {
        case general
        case radialMenu
        case preview
        case keybindings
        case excludedApps
        case more
    }
}
