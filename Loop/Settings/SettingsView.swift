//
//  SettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-11-30.
//

import SwiftUI
import Sparkle

struct SettingsView: View {
    @State var currentSettingsTab = SettingTab.general
    private let updater = SoftwareUpdater()
    private var appListManager = AppListManager()

    var body: some View {
        TabView(selection: $currentSettingsTab) {
            GeneralSettingsView()
                .tag(SettingTab.general)
                .tabItem {
                    Image(systemName: "gear")
                    Text("General")
                }
                .frame(width: 450)

            RadialMenuSettingsView()
                .tag(SettingTab.radialMenu)
                .tabItem {
                    Image(.loop)
                    Text("Radial Menu")
                }
                .frame(width: 450)

            PreviewSettingsView()
                .tag(SettingTab.preview)
                .tabItem {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Preview")
                }
                .frame(width: 450)

            KeybindingsSettingsView()
                .tag(SettingTab.keybindings)
                .tabItem {
                    Image(systemName: "keyboard")
                    Text("Keybindings")
                }
                .frame(width: 500)
                .frame(minHeight: 500, maxHeight: 680)

            ExcludeListSettingsView()
                .tag(SettingTab.excludeList)
                .tabItem {
                    Image(systemName: "xmark.app")
                    Text("Excluded Apps")
                }
                .environmentObject(appListManager)
                .frame(width: 500)
                .frame(maxHeight: 680)

            MoreSettingsView()
                .tag(SettingTab.more)
                .tabItem {
                    Image(systemName: "ellipsis.circle")
                    Text("More")
                }
                .environmentObject(updater)
                .frame(width: 450)
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    enum SettingTab: Int {
        case general
        case radialMenu
        case preview
        case keybindings
        case excludeList
        case more
    }
}
