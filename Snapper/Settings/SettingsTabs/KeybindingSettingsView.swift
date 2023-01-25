//
//  KeybindingSettingsView.swift
//  Snapper
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import KeyboardShortcuts

struct KeybindingSettingsView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Resize Window")
                .fontWeight(.bold)
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                    RoundedRectangle(cornerRadius: 5)
                        .foregroundColor(Color(.systemGray).opacity(0.03))
                    
                    VStack {
                        HStack {
                            Text("Maximize")
                            Spacer()
                            KeyboardShortcuts.Recorder("", name: .resizeMaximize)
                        }
                    }
                    .padding(10)
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                    RoundedRectangle(cornerRadius: 5)
                        .foregroundColor(Color(.systemGray).opacity(0.03))
                    
                    VStack {
                        HStack {
                            Text("Top Half")
                            Spacer()
                            KeyboardShortcuts.Recorder("", name: .resizeTopHalf)
                        }
                        Divider()
                        HStack {
                            Text("Right Half")
                            Spacer()
                            KeyboardShortcuts.Recorder("", name: .resizeRightHalf)
                        }
                        Divider()
                        HStack {
                            Text("Bottom Half")
                            Spacer()
                            KeyboardShortcuts.Recorder("", name: .resizeBottomHalf)
                        }
                        Divider()
                        HStack {
                            Text("Left Half")
                            Spacer()
                            KeyboardShortcuts.Recorder("", name: .resizeLeftHalf)
                        }
                    }
                    .padding(10)
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                    RoundedRectangle(cornerRadius: 5)
                        .foregroundColor(Color(.systemGray).opacity(0.03))
                    
                    VStack {
                        HStack {
                            Text("Top Right Quarter")
                            Spacer()
                            KeyboardShortcuts.Recorder("", name: .resizeTopRightQuarter)
                        }
                        Divider()
                        HStack {
                            Text("Top Left Quarter")
                            Spacer()
                            KeyboardShortcuts.Recorder("", name: .resizeTopLeftQuarter)
                        }
                        Divider()
                        HStack {
                            Text("Bottom Right Quarter")
                            Spacer()
                            KeyboardShortcuts.Recorder("", name: .resizeBottomRightQuarter)
                        }
                        Divider()
                        HStack {
                            Text("Bottom Left Quarter")
                            Spacer()
                            KeyboardShortcuts.Recorder("", name: .resizeBottomLeftQuarter)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .padding(20)
    }
}

struct KeybindingSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        KeybindingSettingsView()
    }
}
