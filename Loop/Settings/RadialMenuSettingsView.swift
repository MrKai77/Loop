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
                Toggle("Show Radial Menu when looping", isOn: $radialMenuVisibility)

                Toggle("Disable cursor interaction", isOn: $disableCursorInteraction)
                    .disabled(!radialMenuVisibility)
                    .foregroundColor(!radialMenuVisibility ? .secondary : nil)
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
                    .init(localized: .init("Crisp Value Adjuster: Corner Radius", defaultValue: "Corner radius")),
                    value: Binding(
                        get: {
                            radialMenuCornerRadius
                        },
                        set: {
                            radialMenuCornerRadius = $0
                            radialMenuThickness = min(radialMenuThickness, radialMenuCornerRadius - 1)
                        }
                    ),
                    sliderRange: 30...50,
                    postscript: .init(localized: .init("px", defaultValue: "px")),
                    lowerClamp: true,
                    upperClamp: true
                )
                CrispValueAdjuster(
                    .init(localized: .init("Crisp Value Adjuster: Thickness", defaultValue: "Thickness")),
                    value: Binding(
                        get: {
                            radialMenuThickness
                        },
                        set: {
                            radialMenuThickness = $0
                            radialMenuCornerRadius = max(radialMenuThickness + 1, radialMenuCornerRadius)
                        }
                    ),
                    sliderRange: 10...35,
                    postscript: .init(localized: .init("px", defaultValue: "px")),
                    lowerClamp: true,
                    upperClamp: true
                )
            }
            .disabled(!radialMenuVisibility)
            .foregroundColor(!radialMenuVisibility ? .secondary : nil)
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
