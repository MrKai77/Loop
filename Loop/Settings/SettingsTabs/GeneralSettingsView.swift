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
    
    @Default(.loopLaunchAtLogin) var launchAtLogin {
        didSet {
            if #available(macOS 13.0, *) {
                if (launchAtLogin) {
                    try? SMAppService().register()
                } else {
                    try? SMAppService().unregister()
                }
            } else {
                if !SMLoginItemSetEnabled(LoopHelper.helperBundleID as CFString, launchAtLogin) {
                    fatalError()
                }
            }
        }
    }
    @Default(.isAccessibilityAccessGranted) var isAccessibilityAccessGranted
    @Default(.loopUsesSystemAccentColor) var loopUsesSystemAccentColor
    @Default(.loopAccentColor) var loopAccentColor
    @Default(.loopUsesAccentColorGradient) var loopUsesAccentColorGradient
    @Default(.loopAccentColorGradient) var loopAccentColorGradient
    @Default(.currentIcon) var currentIcon
    @Default(.timesLooped) var timesLooped
    
    let iconManager = IconManager()
    
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Behavior")
                .fontWeight(.medium)
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
                    .background(.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                
                HStack {
                    Text("Launch at login")
                    Spacer()
                    Toggle("", isOn: self.$launchAtLogin)
                        .labelsHidden()
                        .scaleEffect(0.7)
                        .toggleStyle(.switch)
                }
                .padding([.horizontal], 10)
            }
            .frame(height: 38)
            
            
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
                    .background(.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("Loop's Icon")
                            Spacer()
                            Picker("", selection: self.$currentIcon) {
                                Text("Loop").tag("Loop")
                                
                                if (self.timesLooped >= iconManager.timesThatUnlockNewIcons[0]) {
                                    Text("Donut").tag("Donut")
                                }
                                
                                if (self.timesLooped >= iconManager.timesThatUnlockNewIcons[1]) {
                                    Text("Sci-fi").tag("Sci-fi")
                                }
                            }
                            .frame(width: 160)
                        }
                        Text("Loop more to unlock more icons! (You've looped \(self.timesLooped) times!)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding([.horizontal], 10)
                .onChange(of: self.currentIcon) { _ in
                    iconManager.changeIcon(self.currentIcon)
                }
            }
            .frame(height: 65)
            
            Text("Accent Color")
                .fontWeight(.medium)
                .padding(.top, 20)
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
                    .background(.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                
                VStack {
                    HStack {
                        Text("Follow System Accent Color")
                        Spacer()
                        Toggle("", isOn: self.$loopUsesSystemAccentColor)
                            .scaleEffect(0.7)
                            .toggleStyle(.switch)
                    }
                    Divider()
                    Group {
                        HStack {
                            Text("Accent Color")
                            Spacer()
                            ColorPicker("", selection: self.$loopAccentColor, supportsOpacity: false)
                        }
                        Divider()
                        HStack {
                            Text("Use Gradient")
                            Spacer()
                            Toggle("", isOn: self.$loopUsesAccentColorGradient)
                                .scaleEffect(0.7)
                                .toggleStyle(.switch)
                        }
                        Divider()
                        HStack {
                            Text("Gradient Color")
                            Spacer()
                            ColorPicker("", selection: self.$loopAccentColorGradient, supportsOpacity: false)
                        }
                        .disabled(!self.loopUsesAccentColorGradient)
                        .foregroundColor(self.loopUsesAccentColorGradient ? (self.loopUsesSystemAccentColor ? .secondary : nil) : .secondary)
                    }
                    .disabled(self.loopUsesSystemAccentColor)
                    .foregroundColor(self.loopUsesSystemAccentColor ? .secondary : nil)
                }
                .padding(.horizontal, 10)
            }
            .frame(height: 38*4+6)
            
            HStack {
                Text("Permissions")
                    .fontWeight(.medium)
                Spacer()
                if (!self.isAccessibilityAccessGranted) {
                    Button("Refresh", action: {
                        appDelegate.checkAccessibilityAccess(ask: true)
                    })
                }
            }
            .frame(height: 20)
            .padding(.top, 20)
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
                    .background(.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                
                VStack {
                    HStack {
                        Text("Accessibility Access")
                        Spacer()
                        Text(self.isAccessibilityAccessGranted ? "Granted" : "Not Granted")
                        Circle()
                            .frame(width: 8, height: 8)
                            .padding(.trailing, 5)
                            .foregroundColor(self.isAccessibilityAccessGranted ? .green : .red)
                            .shadow(color: self.isAccessibilityAccessGranted ? .green : .red, radius: 8)
                    }
                }
                .padding([.horizontal], 10)
            }
            .frame(height: 38)
        }
        .padding(20)
    }
}
