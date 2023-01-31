//
//  GeneralSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Defaults
import LaunchAtLogin

struct GeneralSettingsView: View {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @ObservedObject private var loopLaunchAtLogin = LaunchAtLogin.observable
    @State var launchAtLogin: Bool = false
    
    @Default(.isAccessibilityAccessGranted) var isAccessibilityAccessGranted
    @Default(.loopUsesSystemAccentColor) var loopUsesSystemAccentColor
    @Default(.loopAccentColor) var loopAccentColor
    @Default(.loopUsesAccentColorGradient) var loopUsesAccentColorGradient
    @Default(.loopAccentColorGradient) var loopAccentColorGradient
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Behavior")
                .fontWeight(.medium)
            ZStack {
                Rectangle()
                    .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
                    .background(.secondary.opacity(0.05))
                    .cornerRadius(5)
                
                HStack {
                    Text("Launch at login")
                    Spacer()
                    Toggle("", isOn: self.$launchAtLogin)
                        .scaleEffect(0.7)
                        .toggleStyle(.switch)
                }
                .padding([.horizontal], 10)
                .onAppear {
                    self.launchAtLogin = loopLaunchAtLogin.isEnabled
                }
                .onChange(of: self.launchAtLogin) { _ in
                    loopLaunchAtLogin.isEnabled = self.launchAtLogin
                }
            }
            .frame(height: 38)
            
            Text("Accent Color")
                .fontWeight(.medium)
                .padding(.top, 20)
            ZStack {
                Rectangle()
                    .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
                    .background(.secondary.opacity(0.05))
                    .cornerRadius(5)
                
                VStack {
                    HStack {
                        Text("Follow System Accent Color")
                        Spacer()
                        Toggle("", isOn: self.$loopUsesSystemAccentColor)
                            .scaleEffect(0.7)
                            .toggleStyle(.switch)
                    }
                    Divider()
                    VStack {
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
                Rectangle()
                    .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
                    .background(.secondary.opacity(0.05))
                    .cornerRadius(5)
                
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
