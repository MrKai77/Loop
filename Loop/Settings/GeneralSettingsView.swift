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
    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.customAccentColor) var customAccentColor
    @Default(.useGradient) var useGradient
    @Default(.gradientColor) var gradientColor
    @Default(.currentIcon) var currentIcon
    @Default(.timesLooped) var timesLooped
    @Default(.animateWindowResizes) var animateWindowResizes
    @Default(.windowPadding) var windowPadding
    @Default(.windowSnapping) var windowSnapping
    @Default(.animationConfiguration) var animationConfiguration

    @State var isAccessibilityAccessGranted = false
    @State var isScreenRecordingAccessGranted = false

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _ in
                        if launchAtLogin {
                            try? SMAppService().register()
                        } else {
                            try? SMAppService().unregister()
                        }
                    }
            }

            Section {
                Toggle(isOn: $windowSnapping) {
                    HStack {
                        Text("Window Snapping")
                        BetaIndicator("BETA")
                    }
                }

                Toggle(isOn: $animateWindowResizes) {
                    HStack {
                        Text("Animate windows being resized")
                        BetaIndicator("BETA")
                    }
                }
                .onChange(of: animateWindowResizes) { _ in
                    if animateWindowResizes == true {
                        PermissionsManager.ScreenRecording.requestAccess()
                    }
                }

                Slider(value: $windowPadding,
                       in: 0...20,
                       step: 2,
                       minimumValueLabel: Text("0px"),
                       maximumValueLabel: Text("20px")) {
                    Text("Window Padding")
                }
            }

            Section {
                Picker("Animation Speed", selection: $animationConfiguration) {
                    ForEach(AnimationConfiguration.allCases) { configuration in
                        Text(configuration.name)
                    }
                }
            }

            Section("Loop's icon") {
                VStack(alignment: .leading) {
                    Picker("Selected icon:", selection: $currentIcon) {
                        ForEach(IconManager.returnUnlockedIcons(), id: \.self) { icon in
                            HStack {
                                Image(nsImage: NSImage(named: icon.iconName)!)
                                Text(icon.name ??  IconManager.nameWithoutPrefix(name: icon.iconName))
                            }
                            .tag(icon.iconName)
                        }
                    }
                    Text("Loop more to unlock more icons! (You've looped \(timesLooped) times!)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .onChange(of: self.currentIcon) { _ in
                    IconManager.refreshCurrentAppIcon()
                }
            }

            Section("Accent Color") {
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

            Section(content: {
                HStack {
                    Text("Accessibility Access")
                    Spacer()
                    Text(isAccessibilityAccessGranted ? "Granted" : "Not Granted")
                    Circle()
                        .frame(width: 8, height: 8)
                        .padding(.trailing, 5)
                        .foregroundColor(isAccessibilityAccessGranted ? .green : .red)
                        .shadow(color: isAccessibilityAccessGranted ? .green : .red, radius: 8)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Screen Recording Access")
                        Spacer()
                        Text(isScreenRecordingAccessGranted ? "Granted" : "Not Granted")
                        Circle()
                            .frame(width: 8, height: 8)
                            .padding(.trailing, 5)
                            .foregroundColor(isScreenRecordingAccessGranted ? .green : .red)
                            .shadow(color: isScreenRecordingAccessGranted ? .green : .red, radius: 8)
                    }
                    Text("This is only needed to animate windows being resized.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }, header: {
                HStack {
                    Text("Permissions")

                    Spacer()

                    Button("Request Access", action: {
                        PermissionsManager.requestAccess()
                        self.isAccessibilityAccessGranted = PermissionsManager.Accessibility.getStatus()
                        self.isScreenRecordingAccessGranted = PermissionsManager.ScreenRecording.getStatus()
                    })
                    .buttonStyle(.link)
                    .foregroundStyle(Color.accentColor)
                    .disabled(isAccessibilityAccessGranted && isScreenRecordingAccessGranted)
                    .opacity(isAccessibilityAccessGranted ? isScreenRecordingAccessGranted ? 0.6 : 1 : 1)
                    .help("Refresh the current accessibility permissions")
                    .onAppear {
                        self.isAccessibilityAccessGranted = PermissionsManager.Accessibility.getStatus()
                        self.isScreenRecordingAccessGranted = PermissionsManager.ScreenRecording.getStatus()

                        if !isScreenRecordingAccessGranted {
                            self.animateWindowResizes = false
                        }
                    }
                }
            })
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
