//
//  PreviewConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import Defaults
import Luminare
import SwiftUI

class PreviewConfigurationModel: ObservableObject {
    @Published var previewVisibility = Defaults[.previewVisibility] {
        didSet {
            Defaults[.previewVisibility] = previewVisibility

            // We can't move the cursor with the window if the window is going to be moving everywhere
            if !previewVisibility {
                Defaults[.moveCursorWithWindow] = false
            }
        }
    }

    @Published var previewPadding = Defaults[.previewPadding] {
        didSet { Defaults[.previewPadding] = previewPadding }
    }

    @Published var previewCornerRadius = Defaults[.previewCornerRadius] {
        didSet { Defaults[.previewCornerRadius] = previewCornerRadius }
    }

    @Published var previewBorderThickness = Defaults[.previewBorderThickness] {
        didSet { Defaults[.previewBorderThickness] = previewBorderThickness }
    }
}

struct PreviewConfigurationView: View {
    @StateObject private var model = PreviewConfigurationModel()

    var body: some View {
        LuminareSection {
            LuminareToggle(
                "Show preview when looping",
                info: model.previewVisibility ? nil : .init("Window snapping will still use the preview."),
                isOn: $model.previewVisibility
            )

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
