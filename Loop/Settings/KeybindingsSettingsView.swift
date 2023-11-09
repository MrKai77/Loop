//
//  KeybindingsSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-28.
//

import Foundation

import SwiftUI
import Defaults

struct KeybindingsSettingsView: View {

    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.customAccentColor) var customAccentColor
    @Default(.preferMinimizeWithScrollDown) var preferMinimizeWithScrollDown

    var body: some View {
        Form {
            Section("Keybinds") {
                KeybindCustomizationView()
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
