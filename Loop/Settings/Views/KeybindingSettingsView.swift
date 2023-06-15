//
//  KeybindingSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import KeyboardShortcuts

struct KeybindingSettingsView: View {
    var body: some View {
        Form {
            Section("Keybindings") {
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
        .formStyle(.grouped)
    }
}
