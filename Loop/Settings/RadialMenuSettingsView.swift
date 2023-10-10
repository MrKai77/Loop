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

    var body: some View {
        Form {
            Section("Behavior") {
                RadialMenuView(
                    frontmostWindow: nil,
                    previewMode: true,
                    timer: Timer.publish(every: 1,
                                         on: .main,
                                         in: .common).autoconnect()
                )
            }

            Section(content: {
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
            }, footer: {
                HStack {
                    Text("Customize Loop's trigger key in the Keybindings tab!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.leading, 10)
            })
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
