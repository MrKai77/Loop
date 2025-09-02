//
//  RadialMenuConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import Defaults
import Luminare
import SwiftUI

struct RadialMenuConfigurationView: View {
    @Default(.radialMenuVisibility) private var radialMenuVisibility
    @Default(.radialMenuCornerRadius) private var radialMenuCornerRadius
    @Default(.radialMenuThickness) private var radialMenuThickness

    var body: some View {
        LuminareSection {
            LuminareToggle("Radial menu", isOn: $radialMenuVisibility)

            if radialMenuVisibility {
                LuminareSlider(
                    "Corner radius",
                    value: $radialMenuCornerRadius.doubleBinding,
                    in: 30...50,
                    format: .number.precision(.fractionLength(0...0)),
                    clampsUpper: false,
                    clampsLower: false,
                    suffix: Text("px")
                )
                .onChange(of: radialMenuCornerRadius) { _ in
                    if radialMenuCornerRadius - 1 < radialMenuThickness {
                        radialMenuThickness = radialMenuCornerRadius - 1
                    }
                }

                LuminareSlider(
                    "Thickness",
                    value: $radialMenuThickness.doubleBinding,
                    in: 10...35,
                    format: .number.precision(.fractionLength(0...0)),
                    clampsUpper: false,
                    clampsLower: false,
                    suffix: Text("px")
                )
                .onChange(of: radialMenuThickness) { _ in
                    if radialMenuThickness + 1 > radialMenuCornerRadius {
                        radialMenuCornerRadius = radialMenuThickness + 1
                    }
                }
            }
        }
        .animation(.smooth(duration: 0.25), value: radialMenuVisibility)
    }
}
