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
    
    @Default(.loopLaunchAtLogin) var launchAtLogin
    @Default(.isAccessibilityAccessGranted) var isAccessibilityAccessGranted
    @Default(.loopUsesSystemAccentColor) var loopUsesSystemAccentColor
    @Default(.loopAccentColor) var loopAccentColor
    @Default(.loopUsesAccentColorGradient) var loopUsesAccentColorGradient
    @Default(.loopAccentColorGradient) var loopAccentColorGradient
    @Default(.currentIcon) var currentIcon
    @Default(.timesLooped) var timesLooped
    
    let iconManager = IconManager()
    let accessibilityAccessManager = AccessibilityAccessManager()
    
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
            
            Section("Loop's icon") {
                VStack(alignment: .leading) {
                    Picker("Selected icon:", selection: $currentIcon) {
                        ForEach(iconManager.returnUnlockedIcons(), id: \.self) { icon in
                            Text(iconManager.nameWithoutPrefix(name: icon)).tag(icon)
                        }
                    }
                    Text("Loop more to unlock more icons! (You've looped \(timesLooped) times!)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
            }
            
            Section("Accent Color") {
                Toggle("Follow System Accent Color", isOn: $loopUsesSystemAccentColor)
                
                Group {
                    ColorPicker("Accent Color", selection: $loopAccentColor, supportsOpacity: false)
                    Toggle("Use Gradient", isOn: $loopUsesAccentColorGradient)
                    ColorPicker("Gradient's color", selection: $loopAccentColorGradient, supportsOpacity: false)
                        .disabled(!loopUsesAccentColorGradient)
                        .foregroundColor(loopUsesAccentColorGradient ? (loopUsesSystemAccentColor ? .secondary : nil) : .secondary)
                }
                .disabled(loopUsesSystemAccentColor)
                .foregroundColor(loopUsesSystemAccentColor ? .secondary : nil)
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
            }, header: {
                HStack {
                    Text("Permissions")
                    
                    Spacer()
                    
                    Button("Refresh Status", action: {
                        accessibilityAccessManager.checkAccessibilityAccess(ask: true)
                    })
                    .buttonStyle(.link)
                    .disabled(isAccessibilityAccessGranted)
                }
            })
        }
        .formStyle(.grouped)
    }
}
