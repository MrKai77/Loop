//
//  PreviewConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import SwiftUI
import Luminare
import Defaults

class PreviewConfigurationModel: ObservableObject {
    @Published var previewVisibility = Defaults[.previewVisibility] {
        didSet {
            Defaults[.previewVisibility] = previewVisibility
        }
    }
    @Published var previewPadding = Defaults[.previewPadding] {
        didSet {
            Defaults[.previewPadding] = previewPadding
        }
    }
    @Published var previewCornerRadius = Defaults[.previewCornerRadius] {
        didSet {
            Defaults[.previewCornerRadius] = previewCornerRadius
        }
    }
    @Published var previewBorderThickness = Defaults[.previewBorderThickness] {
        didSet {
            Defaults[.previewBorderThickness] = previewBorderThickness
        }
    }
}

struct PreviewConfigurationView: View {
    @StateObject private var model = PreviewConfigurationModel()

    var body: some View {
        LuminareSection {
            LuminareToggle("Show preview when looping", isOn: $model.previewVisibility)

            LuminareValueAdjuster(
                "Padding",
                value: $model.previewPadding,
                sliderRange: 0...20,
                suffix: "px",
                lowerClamp: true,
                upperClamp: true
            )

            LuminareValueAdjuster(
                "Corner radius",
                value: $model.previewCornerRadius,
                sliderRange: 0...20,
                suffix: "px",
                lowerClamp: true,
                upperClamp: true
            )

            LuminareValueAdjuster(
                "Border thickness",
                value: $model.previewBorderThickness,
                sliderRange: 0...10,
                suffix: "px",
                lowerClamp: true,
                upperClamp: true
            )
        }
    }
}
