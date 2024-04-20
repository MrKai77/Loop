//
//  RadialMenuConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import SwiftUI
import Luminare
import Defaults

struct RadialMenuConfigurationView: View {
    @Default(.radialMenuVisibility) var radialMenuVisibility
    @Default(.disableCursorInteraction) var disableCursorInteraction
    @Default(.radialMenuCornerRadius) var radialMenuCornerRadius
    @Default(.radialMenuThickness) var radialMenuThickness

    var body: some View {
        LuminareSection {
            LuminareToggle("Radial menu", isOn: $radialMenuVisibility)
            LuminareToggle("Disable cursor interaction", isOn: $disableCursorInteraction)

            LuminareValueAdjuster(
                "Corner radius",
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
                suffix: "px",
                lowerClamp: true,
                upperClamp: true
            )

            LuminareValueAdjuster(
                "Corner radius",
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
                suffix: "px",
                lowerClamp: true,
                upperClamp: true
            )
        }
    }
}
