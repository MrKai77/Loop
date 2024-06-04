//
//  GeneralSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import Defaults
import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Default(.launchAtLogin) var launchAtLogin
    @Default(.hideMenuBarIcon) var hideMenuBarIcon
    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.customAccentColor) var customAccentColor
    @Default(.useGradient) var useGradient
    @Default(.gradientColor) var gradientColor
    @Default(.currentIcon) var currentIcon
    @Default(.notificationWhenIconUnlocked) var notificationWhenIconUnlocked
    @Default(.timesLooped) var timesLooped
    @Default(.padding) var padding
    @Default(.windowSnapping) var windowSnapping
    @Default(.animationConfiguration) var animationConfiguration
    @Default(.restoreWindowFrameOnDrag) var restoreWindowFrameOnDrag
    @Default(.resizeWindowUnderCursor) var resizeWindowUnderCursor
    @Default(.focusWindowOnResize) var focusWindowOnResize

    @State var userDisabledLoopNotifications: Bool = false
    @State var iconFooter: String?

    @State var isConfiguringPadding: Bool = false

    var body: some View {
        Form {
            Section("App Icon") {
                VStack(alignment: .leading) {
                    VStack(alignment: .leading) {
                        Text("Loop more to unlock new icons! (You've looped \(timesLooped) times!)")

                        if let iconFooter {
                            Text(iconFooter)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                }
                .onAppear {
                    iconFooter = IconManager.currentAppIcon.footer
                }
                .onChange(of: currentIcon) { _ in
                    IconManager.refreshCurrentAppIcon()
                    iconFooter = IconManager.currentAppIcon.footer
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
