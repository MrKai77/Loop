//
//  KeybindingSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Defaults
import KeyboardShortcuts

struct KeybindingSettingsView: View {
    
    @Default(.useKeyboardShortcuts) var useKeyboardShortcuts
    
    var body: some View {
        Form {
            Section("Keybindings") {
                Toggle("Enabled", isOn: $useKeyboardShortcuts)
            }
            
            Group {
                Section {
                    KeyboardShortcuts.Recorder("Maximize", name: .maximize)
                }
                
                Section {
                    KeyboardShortcuts.Recorder("Top Half", name: .topHalf)
                    KeyboardShortcuts.Recorder("Bottom Half", name: .bottomHalf)
                    KeyboardShortcuts.Recorder("Right Half", name: .rightHalf)
                    KeyboardShortcuts.Recorder("Left Half", name: .leftHalf)
                }
                
                Section {
                    KeyboardShortcuts.Recorder("Top Right Quarter", name: .topRightQuarter)
                    KeyboardShortcuts.Recorder("Top Left Quarter", name: .topLeftQuarter)
                    KeyboardShortcuts.Recorder("Bottom Right Quarter", name: .bottomRightQuarter)
                    KeyboardShortcuts.Recorder("Bottom Left Quarter", name: .bottomLeftQuarter)
                }
                
                Section {
                    KeyboardShortcuts.Recorder("Right Third", name: .rightThird)
                    KeyboardShortcuts.Recorder("Right Two Thirds", name: .rightTwoThirds)
                    KeyboardShortcuts.Recorder("Center Third", name: .horizontalCenterThird)
                    KeyboardShortcuts.Recorder("Left Two Thirds", name: .leftTwoThirds)
                    KeyboardShortcuts.Recorder("Left Third", name: .leftThird)
                }
            }
            .disabled(!useKeyboardShortcuts)
            .foregroundColor(!useKeyboardShortcuts ? .secondary : nil)
        }
        .formStyle(.grouped)
    }
}
