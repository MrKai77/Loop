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
    @Default(.snapperTrigger) var snapperTrigger
    @Default(.isAccessibilityAccessGranted) var isAccessibilityAccessGranted
    
    @State private var selectedSnapperTrigger = "􀆪 Function"
    let snapperTriggerKeyOptions = [
        "􀆍 Left Control": 262401,
        "􀆕 Left Option": 524576,
        "􀆕 Right Option": 524608,
        "􀆔 Right Command": 1048848,
        "􀆡 Caps Lock": 270592,
        "􀆪 Function": 8388864]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Behavior")
                .fontWeight(.medium)
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
                RoundedRectangle(cornerRadius: 5)
                    .foregroundColor(Color(.systemGray).opacity(0.03))
                
                VStack {
                    HStack {
                        Text("Launch at login")
                        Spacer()
                        Toggle("", isOn: $launchAtLogin.isEnabled)
                            .scaleEffect(0.7)
                            .toggleStyle(.switch)
                    }
                }
                .padding([.leading], 10)
                .padding([.trailing], 3)
            }
            .frame(height: 35)
            
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
                RoundedRectangle(cornerRadius: 5)
                    .foregroundColor(Color(.systemGray).opacity(0.03))
                
                VStack {
//                    VStack(alignment: .leading, spacing: 5) {
//                        HStack {
//                            Text("Trigger Snapper")
//                            Spacer()
//                            Picker("", selection: $selectedSnapperTrigger) {
//                                ForEach(Array(snapperTriggerKeyOptions.keys), id: \.self) {
//                                    Text($0)
//                                }
//                            }
//                            .frame(width: 160)
//                        }
//                        if (self.selectedSnapperTrigger == "􀆡 Caps Lock") {
//                            Text("Remap Caps Lock to Control in System Settings.")
//                                .font(.caption)
//                                .opacity(0.5)
//                        }
//                    }
//                    .onAppear {
//                        for dictEntry in snapperTriggerKeyOptions {
//                            if (dictEntry.value == self.snapperTrigger) {
//                                self.selectedSnapperTrigger = dictEntry.key
//                            }
//                        }
//                    }
//                    .onChange(of: self.selectedSnapperTrigger) { _ in
//                        for dictEntry in snapperTriggerKeyOptions {
//                            if (dictEntry.key == self.selectedSnapperTrigger) {
//                                self.snapperTrigger = dictEntry.value
//                            }
//                        }
//                    }
//
//                    Divider()
                    
                    HStack {
                        Text("Show Preview when snapping")
                        Spacer()
                        Toggle("", isOn: $showPreviewWhenSnapping)
                            .scaleEffect(0.7)
                            .toggleStyle(.switch)
                    }
                }
                .padding([.leading], 10)
                .padding([.trailing], 3)
            }
            .frame(height: 35)
            
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
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
                RoundedRectangle(cornerRadius: 5)
                    .foregroundColor(Color(.systemGray).opacity(0.03))
                
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
                    .frame(height: 35)
                }
                .padding([.leading], 10)
                .padding([.trailing], 5)
            }
            .frame(height: 35)
        }
        .padding(20)
    }
}

struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsView()
    }
}
