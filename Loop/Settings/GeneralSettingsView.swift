//
//  GeneralSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Defaults
import ServiceManagement

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
            Section(String(localized: "Behavior", comment: "Title in settings window")) {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _ in
                        if launchAtLogin {
                            try? SMAppService().register()
                        } else {
                            try? SMAppService().unregister()
                        }
                    }

                VStack(alignment: .leading) {
                    Toggle("Hide menubar icon", isOn: $hideMenuBarIcon)

                    if hideMenuBarIcon {
                        Text("Re-open Loop to see this window.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }

            Section {
                Toggle("Window Snapping", isOn: $windowSnapping)

                HStack {
                    Text("Window Padding")
                    Spacer()
                    Button("Configure…") {
                        self.isConfiguringPadding = true
                    }
                }
                .sheet(isPresented: self.$isConfiguringPadding) {
                    PaddingConfigurationView(isSheetShown: $isConfiguringPadding, paddingModel: $padding)
                }

                Toggle(
                    "Restore window frame on drag",
                    isOn: $restoreWindowFrameOnDrag
                )

                Toggle(isOn: $resizeWindowUnderCursor) {
                    VStack(alignment: .leading) {
                        Text("Resize window under cursor")
                        Text(resizeWindowUnderCursor ?
                            String(
                                localized: "Resizes window under cursor, and uses the frontmost window as backup.",
                                comment: "Description of a toggle button"
                            ) :
                            String(
                                localized: "Resizes frontmost window.",
                                comment: "Description of a toggle button"
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                if resizeWindowUnderCursor {
                    Toggle("Focus window on resize", isOn: $focusWindowOnResize)
                }
            }

            Section {
                Picker("Animation Speed", selection: $animationConfiguration) {
                    ForEach(AnimationConfiguration.allCases) { configuration in
                        Text(configuration.name)
                    }
                }
            }

            Section(String(localized: "Loop's icon")) {
                VStack(alignment: .leading) {
                    Picker("Selected icon:", selection: $currentIcon) {
                        ForEach(IconManager.returnUnlockedIcons(), id: \.self) { icon in
                            HStack {
                                Image(nsImage: NSImage(named: icon.iconName)!)
                                Text(icon.name)
                            }
                            .tag(icon.iconName)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Loop more to unlock new icons! (You've looped \(timesLooped) times!)")

                        if let iconFooter = iconFooter {
                            Text(iconFooter)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                }
                .onAppear {
                    self.iconFooter = IconManager.currentAppIcon.footer
                }
                .onChange(of: self.currentIcon) { _ in
                    IconManager.refreshCurrentAppIcon()
                    self.iconFooter = IconManager.currentAppIcon.footer
                }

                Toggle(
                    "Notify me when new icons are unlocked",
                    isOn: Binding(
                        get: {
                            self.notificationWhenIconUnlocked
                        },
                        set: {
                            if $0 {
                                AppDelegate.sendNotification(
                                    String(localized: "Loop"),
                                    String(localized: "You will now be notified when you unlock a new icon.")
                                )

                                let areNotificationsEnabled = AppDelegate.areNotificationsEnabled()
                                self.notificationWhenIconUnlocked = areNotificationsEnabled

                                if !areNotificationsEnabled {
                                    self.userDisabledLoopNotifications = true
                                }
                            } else {
                                self.notificationWhenIconUnlocked = $0
                            }
                        }
                    )
                )
                .onAppear {
                    if self.notificationWhenIconUnlocked {
                        self.notificationWhenIconUnlocked = AppDelegate.areNotificationsEnabled()
                    }
                }
                .popover(isPresented: self.$userDisabledLoopNotifications,
                         arrowEdge: .bottom,
                         content: {
                    VStack(alignment: .center) {
                        Text("Loop's notification permissions are currently disabled.")
                        Text("Please turn them on in System Settings.")
                        Button("Open Notification Settings") {
                            NSWorkspace.shared.open(
                                URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!
                            )
                        }
                    }
                    .padding(8)

                })
            }

            Section(String(localized: "Accent Color", comment: "Title in settings window")) {
                Toggle("Use System Accent Color", isOn: $useSystemAccentColor)

                if !useSystemAccentColor {
                    ColorPicker("Custom Accent Color", selection: $customAccentColor, supportsOpacity: false)
                }

                Toggle("Use Gradient", isOn: $useGradient)

                if !useSystemAccentColor && useGradient {
                    ColorPicker("Custom Gradient color", selection: $gradientColor, supportsOpacity: false)
                        .foregroundColor(
                            useGradient ? (useSystemAccentColor ? .secondary : nil) : .secondary
                        )
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
