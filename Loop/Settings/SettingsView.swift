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
    private let updater = SoftwareUpdater()
    private var appListManager = AppListManager()

    var body: some View {
        TabView(selection: $currentSettingsTab) {
            GeneralSettingsView()
                .tag(SettingsTab.general)
                .tabItem {
                    Image(systemName: "gear")
                    Text("General", comment: "Title in settings window")
                }
                .frame(width: 450)

            RadialMenuSettingsView()
                .tag(SettingsTab.radialMenu)
                .tabItem {
                    Image(.loop)
                    Text("Radial Menu", comment: "Title in settings window")
                }
                .frame(width: 450)

            PreviewSettingsView()
                .tag(SettingsTab.preview)
                .tabItem {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Preview", comment: "Title in settings window")
                }
                .frame(width: 450)

            KeybindingsSettingsView()
                .tag(SettingsTab.keybinds)
                .tabItem {
                    Image(systemName: "keyboard")
                    Text("Keybinds", comment: "Title in settings window")
                }
                .frame(width: 500)
                .frame(minHeight: 500, maxHeight: 680)

            ExcludeListSettingsView()
                .tag(SettingsTab.excludedApps)
                .tabItem {
                    Image(systemName: "xmark.app")
                    Text("Excluded Apps", comment: "Title in settings window")
                }
                .environmentObject(appListManager)
                .frame(width: 450)
                .frame(maxHeight: 680)

            MoreSettingsView()
                .tag(SettingsTab.more)
                .tabItem {
                    Image(systemName: "ellipsis.circle")
                    Text("More", comment: "Title in settings window")
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
        case keybinds
        case excludedApps
        case more
    }
}
