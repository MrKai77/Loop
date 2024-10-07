//
//  RadialMenuConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import Defaults
import Luminare
import SwiftUI

class RadialMenuConfigurationModel: ObservableObject {
    @Published var radialMenuVisibility = Defaults[.radialMenuVisibility] {
        didSet {
            Defaults[.radialMenuVisibility] = radialMenuVisibility
        }
    }

    @Published var radialMenuCornerRadius = Defaults[.radialMenuCornerRadius] {
        didSet {
            Defaults[.radialMenuCornerRadius] = radialMenuCornerRadius

            if radialMenuCornerRadius - 1 < radialMenuThickness {
                radialMenuThickness = radialMenuCornerRadius - 1
            }
        }
    }

    @Published var radialMenuThickness = Defaults[.radialMenuThickness] {
        didSet {
            Defaults[.radialMenuThickness] = radialMenuThickness

            if radialMenuThickness + 1 > radialMenuCornerRadius {
                radialMenuCornerRadius = radialMenuThickness + 1
            }
        }
    }
}

struct RadialMenuConfigurationView: View {
    @StateObject private var model = RadialMenuConfigurationModel()

    var body: some View {
        LuminareSection {
            LuminareToggle("Radial menu", isOn: $model.radialMenuVisibility)

            if model.radialMenuVisibility {
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
}
