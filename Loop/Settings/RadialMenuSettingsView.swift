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
    @Default(.hideUntilDirectionIsChosen) var hideUntilDirectionIsChosen
    @Default(.disableCursorInteraction) var disableCursorInteraction

    var body: some View {
        Form {
            Section("Appearance") {
                Toggle("Show Radial Menu when looping", isOn: $radialMenuVisibility)
            }

            Section {
                ZStack {
                    VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                        .ignoresSafeArea()
                        .padding(-10)

                    RadialMenuView(
                        previewMode: true,
                        window: nil
                    )
                }
            }
            .opacity(radialMenuVisibility ? 1 : 0.5)

            Section {
                CrispValueAdjuster(
                    "Corner Radius",
                    value: $radialMenuCornerRadius,
                    sliderRange: 30...50,
                    postscript: "px",
                    lowerClamp: true,
                    upperClamp: true
                )
                CrispValueAdjuster(
                    "Thickness",
                    value: $radialMenuThickness,
                    sliderRange: 10...35,
                    postscript: "px",
                    lowerClamp: true,
                    upperClamp: true
                )
            }
            .disabled(!radialMenuVisibility)
            .foregroundColor(!radialMenuVisibility ? .secondary : nil)

            Section {
                Toggle("Hide until direction is chosen", isOn: $hideUntilDirectionIsChosen)
                Toggle("Disable cursor interaction", isOn: $disableCursorInteraction)
            }
            .disabled(!radialMenuVisibility)
            .foregroundColor(!radialMenuVisibility ? .secondary : nil)
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
