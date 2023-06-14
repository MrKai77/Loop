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
                KeyboardShortcuts.Recorder("Maximize", name: .resizeMaximize)
            }
            
            Section {
                KeyboardShortcuts.Recorder("Top Half", name: .resizeTopHalf)
                KeyboardShortcuts.Recorder("Bottom Half", name: .resizeBottomHalf)
                KeyboardShortcuts.Recorder("Right Half", name: .resizeRightHalf)
                KeyboardShortcuts.Recorder("Left Half", name: .resizeLeftHalf)
            }
            
            Section {
                KeyboardShortcuts.Recorder("Top Right Quarter", name: .resizeTopRightQuarter)
                KeyboardShortcuts.Recorder("Top Left Quarter", name: .resizeTopLeftQuarter)
                KeyboardShortcuts.Recorder("Bottom Right Quarter", name: .resizeBottomRightQuarter)
                KeyboardShortcuts.Recorder("Bottom Left Quarter", name: .resizeBottomLeftQuarter)
            }
            
            Section {
                KeyboardShortcuts.Recorder("Right Third", name: .resizeRightThird)
                KeyboardShortcuts.Recorder("Right Two Thirds", name: .resizeRightTwoThirds)
                KeyboardShortcuts.Recorder("Center Third", name: .resizeRLCenterThird)
                KeyboardShortcuts.Recorder("Left Two Thirds", name: .resizeLeftTwoThirds)
                KeyboardShortcuts.Recorder("Left Third", name: .resizeLeftThird)
            }
        }
        .formStyle(.grouped)
    }
}
