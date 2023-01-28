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
    
    @ObservedObject private var launchAtLogin = LaunchAtLogin.observable
    
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
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color("Monochrome").opacity(0.2), lineWidth: 0.5)
                RoundedRectangle(cornerRadius: 5)
                    .foregroundColor(Color("Monochrome").opacity(0.03))
                
                HStack {
                    Text("Launch at login")
                    Spacer()
                    Toggle("", isOn: $launchAtLogin.isEnabled)
                        .scaleEffect(0.7)
                        .toggleStyle(.switch)
                }
                .padding([.horizontal], 10)
            }
            .frame(height: 38)
            
            Text("Accent Color")
                .fontWeight(.medium)
                .padding(.top, 20)
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color("Monochrome").opacity(0.2), lineWidth: 0.5)
                RoundedRectangle(cornerRadius: 5)
                    .foregroundColor(Color("Monochrome").opacity(0.03))
                
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
                        .opacity(self.loopUsesAccentColorGradient ? 1 : 0.5)
                    }
                    .disabled(self.loopUsesSystemAccentColor)
                    .opacity(self.loopUsesSystemAccentColor ? 0.5 : 1)
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
                        appDelegate.checkAccessibilityAccess()
                    })
                }
            }
            .frame(height: 20)
            .padding(.top, 20)
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color("Monochrome").opacity(0.2), lineWidth: 0.5)
                RoundedRectangle(cornerRadius: 5)
                    .foregroundColor(Color("Monochrome").opacity(0.03))
                
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
