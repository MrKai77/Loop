//
//  GeneralSettingsView.swift
//  Snapper
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Defaults
import LaunchAtLogin

struct GeneralSettingsView: View {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @ObservedObject private var launchAtLogin = LaunchAtLogin.observable
    
    @Default(.showPreviewWhenSnapping) var showPreviewWhenSnapping
    @Default(.isAccessibilityAccessGranted) var isAccessibilityAccessGranted
    
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
            
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color("Monochrome").opacity(0.2), lineWidth: 0.5)
                RoundedRectangle(cornerRadius: 5)
                    .foregroundColor(Color("Monochrome").opacity(0.03))
                
                HStack {
                    Text("Show Preview when snapping")
                    Spacer()
                    
                    Toggle("", isOn: $showPreviewWhenSnapping)
                        .scaleEffect(0.7)
                        .toggleStyle(.switch)
                }
                .padding([.horizontal], 10)
            }
            .frame(height: 38)
            
            HStack {
                Text("Permissions")
                    .fontWeight(.medium)
                Spacer()
                Button("Refresh", action: {
                    appDelegate.checkAccessibilityAccess()
                })
            }
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
