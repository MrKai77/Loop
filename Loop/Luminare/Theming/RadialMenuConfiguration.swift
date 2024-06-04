//
//  RadialMenuConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import SwiftUI
import Luminare
import Defaults

class RadialMenuConfigurationModel: ObservableObject {
    @Published var radialMenuVisibility = Defaults[.radialMenuVisibility] {
        didSet {
            Defaults[.radialMenuVisibility] = radialMenuVisibility
        }
    }
    @Published var disableCursorInteraction = Defaults[.disableCursorInteraction] {
        didSet {
            Defaults[.disableCursorInteraction] = disableCursorInteraction
        }
    }
    @Published var radialMenuCornerRadius = Defaults[.radialMenuCornerRadius] {
        didSet {
            Defaults[.radialMenuCornerRadius] = radialMenuCornerRadius
            radialMenuThickness = min(radialMenuThickness, radialMenuCornerRadius - 1)
        }
    }
    @Published var radialMenuThickness = Defaults[.radialMenuThickness] {
        didSet {
            Defaults[.radialMenuThickness] = radialMenuThickness
            radialMenuCornerRadius = max(radialMenuThickness + 1, radialMenuCornerRadius)
        }
    }
}

struct RadialMenuConfigurationView: View {
    @StateObject private var model = RadialMenuConfigurationModel()

    var body: some View {
        LuminareSection {
            LuminareToggle("Radial menu", isOn: $model.radialMenuVisibility)
            LuminareToggle("Disable cursor interaction", isOn: $model.disableCursorInteraction)

            LuminareValueAdjuster(
                "Corner radius",
                value: $model.radialMenuCornerRadius,
                sliderRange: 30...50,
                suffix: "px",
                lowerClamp: true,
                upperClamp: true
            )

            LuminareValueAdjuster(
                "Thickness",
                value: $model.radialMenuThickness,
                sliderRange: 10...35,
                suffix: "px",
                lowerClamp: true,
                upperClamp: true
            )
        }
    }
}
