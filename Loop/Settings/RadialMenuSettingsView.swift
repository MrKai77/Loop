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
                Slider(value: $radialMenuCornerRadius,
                       in: 30...50,
                       step: 3,
                       minimumValueLabel: Text("30px"),
                       maximumValueLabel: Text("50px")) {
                    Text("Corner Radius")
                }
                Slider(
                    value: $radialMenuThickness,
                    in: 10...34,
                    step: 4,
                    minimumValueLabel: Text("10px"),
                    maximumValueLabel: Text("35px")
                ) {
                    Text("Thickness")
                }
            }

            Section {
                Toggle("Hide until direction is chosen", isOn: $hideUntilDirectionIsChosen)
                Toggle("Disable cursor interaction", isOn: $disableCursorInteraction)
            }

            Section {
                Stepper(
                    "Appearance Delay (seconds)",
                    value: self.$radialMenuDelay,
                    in: 0...10,
                    step: 0.1,
                    format: .number
                )
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
