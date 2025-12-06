//
//  SettingsTab.swift
//  Loop
//
//  Created by Kai Azim on 2025-12-06.
//

import Luminare
import SwiftUI

enum SettingsTab: LuminareTabItem, CaseIterable {
    var id: String { title }

    case icon
    case accentColor
    case radialMenu
    case preview

    case behavior
    case keybinds

    case advanced
    case excludedApps
    case about

    var title: String {
        switch self {
        case .icon: .init(localized: "Settings tab: Icon", defaultValue: "Icon")
        case .accentColor: .init(localized: "Settings tab: Accent Color", defaultValue: "Accent Color")
        case .radialMenu: .init(localized: "Settings tab: Radial Menu", defaultValue: "Radial Menu")
        case .preview: .init(localized: "Settings tab: Preview", defaultValue: "Preview")
        case .behavior: .init(localized: "Settings tab: Behavior", defaultValue: "Behavior")
        case .keybinds: .init(localized: "Settings tab: Keybindings", defaultValue: "Keybinds")
        case .advanced: .init(localized: "Settings tab: Advanced", defaultValue: "Advanced")
        case .excludedApps: .init(localized: "Settings tab: Excluded Apps", defaultValue: "Excluded Apps")
        case .about: .init(localized: "Settings tab: About", defaultValue: "About")
        }
    }

    var image: Image {
        switch self {
        case .icon: Image(.squareSparkle)
        case .accentColor: Image(.paintbrush)
        case .radialMenu: Image(.loop)
        case .preview: Image(.sidebarRight2)
        case .behavior: Image(.gear)
        case .keybinds: Image(.command)
        case .advanced: Image(.faceNerdSmile)
        case .excludedApps: Image(.windowLock)
        case .about: Image(.msgSmile2)
        }
    }

    var showIndicator: Bool {
        switch self {
        case .about: Updater.shared.updateState == .available
        default: false
        }
    }

    @ViewBuilder func view() -> some View {
        switch self {
        case .icon: IconConfigurationView()
        case .accentColor: AccentColorConfigurationView()
        case .radialMenu: RadialMenuConfigurationView()
        case .preview: PreviewConfigurationView()
        case .behavior: BehaviorConfigurationView()
        case .keybinds: KeybindsConfigurationView()
        case .advanced: AdvancedConfigurationView()
        case .excludedApps: ExcludedAppsConfigurationView()
        case .about: AboutConfigurationView()
        }
    }

    static let themingTabs: [Self] = [.icon, .accentColor, .radialMenu, .preview]
    static let settingsTabs: [Self] = [.behavior, .keybinds]
    static let loopTabs: [Self] = [.advanced, .excludedApps, .about]
}
