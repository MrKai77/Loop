//
//  RadialMenuSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-25.
//

import SwiftUI
import Defaults

struct RadialMenuSettingsView: View {
    @Default(.radialMenuVisibility) var radialMenuVisibility
    @Default(.radialMenuCornerRadius) var radialMenuCornerRadius
    @Default(.radialMenuThickness) var radialMenuThickness
    @Default(.disableCursorInteraction) var disableCursorInteraction

    var body: some View {
        Form {
            Section("Appearance") {
                Toggle("Disable cursor interaction", isOn: $disableCursorInteraction)
                    .disabled(!radialMenuVisibility)
                    .foregroundColor(!radialMenuVisibility ? .secondary : nil)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
