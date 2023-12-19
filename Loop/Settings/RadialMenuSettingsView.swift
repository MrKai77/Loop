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

    @State var currentResizeDirection: WindowDirection = .cycleTop

    var body: some View {
        Form {
            Section("Appearance") {
                RadialMenuView(
                    frontmostWindow: nil,
                    previewMode: true,
                    timer: Timer.publish(every: 1,
                                         on: .main,
                                         in: .common).autoconnect()
                )
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
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
