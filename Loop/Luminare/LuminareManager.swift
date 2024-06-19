//
//  LuminareManager.swift
//  Loop
//
//  Created by Kai Azim on 2024-05-28.
//

import Defaults
import Luminare
import SwiftUI

class LuminareManager {
    static var window: NSWindow? {
        LuminareManager.luminare.windowController?.window
    }

    static let iconConfiguration = SettingsTab("Icon", Image(._18PxSquareSparkle), IconConfigurationView())
    static let accentColorConfiguration = SettingsTab("Accent Color", Image(._18PxPaintbrush), AccentColorConfigurationView())
    static let radialMenuConfiguration = SettingsTab("Radial Menu", Image("loop"), RadialMenuConfigurationView())
    static let previewConfiguration = SettingsTab("Preview", Image(._18PxSidebarRight2), PreviewConfigurationView())

    static let behaviorConfiguration = SettingsTab("Behavior", Image(._18PxGear), BehaviorConfigurationView())
    static let keybindingsConfiguration = SettingsTab("Keybindings", Image(._18PxCommand), KeybindingsConfigurationView())

    static let advancedConfiguration = SettingsTab("Advanced", Image(._18PxFaceNerdSmile), AdvancedConfigurationView())
    static let excludedAppsConfiguration = SettingsTab("Excluded Apps", Image(._18PxWindowLock), ExcludedAppsConfigurationView())
    static let aboutConfiguration = SettingsTab("About", Image(._18PxMsgSmile2), AboutConfigurationView())

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

    static func processTabChange(_ tab: SettingsTab) {
        DispatchQueue.main.async {
            if tab == radialMenuConfiguration {
                luminare.hidePreview(identifier: "Preview")
                if Defaults[.radialMenuVisibility] {
                    luminare.showPreview(identifier: "RadialMenu")
                } else {
                    luminare.hidePreview(identifier: "RadialMenu")
                }
                return
            }
            if tab == previewConfiguration {
                luminare.showPreview(identifier: "Preview")
                luminare.hidePreview(identifier: "RadialMenu")
                return
            }
            if tab == accentColorConfiguration || tab == behaviorConfiguration {
                luminare.showPreview(identifier: "Preview")
                if Defaults[.radialMenuVisibility] {
                    luminare.showPreview(identifier: "RadialMenu")
                } else {
                    luminare.hidePreview(identifier: "RadialMenu")
                }
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
        AppDelegate.isActive = true
        NSApp.setActivationPolicy(.regular)
    }

    static func fullyClose() {
        luminare.deinitWindow()

        if !Defaults[.showDockIcon] {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
