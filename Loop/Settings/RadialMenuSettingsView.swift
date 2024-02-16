//
//  RadialMenuSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-25.
//

import SwiftUI
import Defaults

struct RadialMenuSettingsView: View {

    @Default(.radialMenuCornerRadius) var radialMenuCornerRadius
    @Default(.radialMenuThickness) var radialMenuThickness
    @Default(.hideUntilDirectionIsChosen) var hideUntilDirectionIsChosen
    @Default(.disableCursorInteraction) var disableCursorInteraction
    @Default(.radialMenuDelay) var radialMenuDelay

    @State var currentResizeDirection: WindowDirection = .cycleTop

    var body: some View {
        Form {
            Section("Appearance") {
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

            Section {
                Toggle("Hide until direction is chosen", isOn: $hideUntilDirectionIsChosen)
                Toggle("Disable cursor interaction", isOn: $disableCursorInteraction)
            }

            Section {
                CrispValueAdjuster(
                    "Appearance Delay",
                    value: $radialMenuDelay,
                    sliderRange: 0...10,
                    postscript: "sec",
                    lowerClamp: true
                )
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
