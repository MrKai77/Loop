//
//  LuminareManager.swift
//  Loop
//
//  Created by Kai Azim on 2024-05-28.
//

import SwiftUI
import Defaults
import Luminare

class LuminareManager {
    static var window: NSWindow? {
        LuminareManager.luminare.windowController?.window
    }

    // swiftlint:disable line_length
    static let iconConfiguration = SettingsTab("Icon", Image(systemName: "sparkle"), IconConfigurationView())
    static let accentColorConfiguration = SettingsTab("Accent Color", Image(systemName: "paintbrush.pointed"), AccentColorConfigurationView())
    static let radialMenuConfiguration = SettingsTab("Radial Menu", Image("loop"), RadialMenuConfigurationView())
    static let previewConfiguration = SettingsTab("Preview", Image(systemName: "rectangle.lefthalf.inset.filled"), PreviewConfigurationView())

    static let behaviorConfiguration = SettingsTab("Behavior", Image(systemName: "gear"), BehaviorConfigurationView())
    static let keybindingsConfiguration = SettingsTab("Keybindings", Image(systemName: "command"), KeybindingsConfigurationView())

    static let advancedConfiguration = SettingsTab("Advanced", Image(systemName: "face.smiling.inverse"), AdvancedConfigurationView())
    static let excludedAppsConfiguration = SettingsTab("Excluded Apps", Image(systemName: "lock.app.dashed"), ExcludedAppsConfigurationView())
    static let aboutConfiguration = SettingsTab("About", Image(systemName: "ellipsis"), AboutConfigurationView())
    // swiftlint:enable line_length

    static var luminare = LuminareSettingsWindow(
        [
            .init("Theming", [
                iconConfiguration,
                accentColorConfiguration,
                radialMenuConfiguration,
                previewConfiguration
            ]),
            .init("Settings", [
                behaviorConfiguration,
                keybindingsConfiguration
            ]),
            .init("Loop", [
                advancedConfiguration,
                excludedAppsConfiguration,
                aboutConfiguration
            ])
        ],
        tint: {
            AppDelegate.isActive ? Color.getLoopAccent(tone: .normal) : Color.systemGray
        },
        didTabChange: processTabChange
    )

    private static func processTabChange(_ tab: SettingsTab? = nil) {
        DispatchQueue.main.async {
            if tab == radialMenuConfiguration {
                luminare.hidePreview(identifier: "Preview")
                luminare.showPreview(identifier: "RadialMenu")
                return
            }
            if tab == previewConfiguration {
                luminare.showPreview(identifier: "Preview")
                luminare.hidePreview(identifier: "RadialMenu")
                return
            }
            if tab == accentColorConfiguration || tab == behaviorConfiguration {
                luminare.showPreview(identifier: "Preview")
                luminare.showPreview(identifier: "RadialMenu")
                return
            }
        }
    }

    static func open() {
        if luminare.windowController == nil {
            luminare.initializeWindow()

            DispatchQueue.main.async {
                luminare.addPreview(
                    content: LuminarePreviewView(),
                    identifier: "Preview",
                    fullSize: true
                )
                luminare.addPreview(
                    content: RadialMenuView(previewMode: true),
                    identifier: "RadialMenu"
                )

                luminare.showPreview(identifier: "Preview")
                luminare.showPreview(identifier: "RadialMenu")
            }
        }

        luminare.show()

        NSApp.setActivationPolicy(.regular)
    }

    static func fullyClose() {
        luminare.deinitWindow()

        if !Defaults[.showDockIcon] {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
