//
//  PreviewConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import SwiftUI
import Luminare
import Defaults

struct PreviewConfigurationView: View {
    @Default(.previewVisibility) var previewVisibility
    @Default(.previewPadding) var previewPadding
    @Default(.previewCornerRadius) var previewCornerRadius
    @Default(.previewBorderThickness) var previewBorderThickness

    var body: some View {
        LuminareSection {
            LuminareToggle("Show preview when looping", isOn: $previewVisibility)

            LuminareValueAdjuster(
                "Padding",
                value: $previewPadding,
                sliderRange: 0...20,
                suffix: "px",
                lowerClamp: true,
                upperClamp: true
            )

            LuminareValueAdjuster(
                "Corner Radius",
                value: $previewCornerRadius,
                sliderRange: 0...20,
                suffix: "px",
                lowerClamp: true,
                upperClamp: true
            )

            LuminareValueAdjuster(
                "Border Thickness",
                value: $previewBorderThickness,
                sliderRange: 0...10,
                suffix: "px",
                lowerClamp: true,
                upperClamp: true
            )
        }
    }
}
