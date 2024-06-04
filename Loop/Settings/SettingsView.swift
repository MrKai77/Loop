//
//  SettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-11-30.
//

import Sparkle
import SwiftUI

struct SettingsView: View {
    @State var currentSettingsTab = SettingsTab.general
    @StateObject private var updater = SoftwareUpdater()

    var body: some View {
        TabView(selection: $currentSettingsTab) {
            GeneralSettingsView()
                .tag(SettingsTab.general)
                .tabItem {
                    Image(systemName: "gear")
                    Text("General")
                }
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
