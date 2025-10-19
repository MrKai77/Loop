//
//  PreviewConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import Defaults
import Luminare
import SwiftUI

struct PreviewConfigurationView: View {
    @Environment(\.luminareAnimation) private var luminareAnimation

    @Default(.previewVisibility) private var previewVisibility
    @Default(.moveCursorWithWindow) private var moveCursorWithWindow
    @Default(.previewPadding) private var previewPadding
    @Default(.previewCornerRadius) private var previewCornerRadius
    @Default(.previewBorderThickness) private var previewBorderThickness

    var body: some View {
        LuminareSection {
            LuminareToggle(
                isOn: Binding(
                    get: {
                        previewVisibility
                    },
                    set: {
                        previewVisibility = $0

                        if !previewVisibility {
                            moveCursorWithWindow = false
                        }
                    }
                )
            ) {
                Text("Show preview when looping")
                    .padding(.trailing, 4)
                    .luminarePopover(attachedTo: .topTrailing, hidden: previewVisibility) {
                        Text("Window snapping will still use the preview.")
                            .padding(6)
                    }
                    .animation(luminareAnimation, value: previewVisibility)
            }

            LuminareSlider(
                "Padding",
                value: $previewPadding.doubleBinding,
                in: 0...20,
                format: .number.precision(.fractionLength(0...0)),
                clampsUpper: false,
                clampsLower: false,
                suffix: Text("px")
            )

            LuminareSlider(
                "Corner radius",
                value: $previewCornerRadius.doubleBinding,
                in: 0...20,
                format: .number.precision(.fractionLength(0...0)),
                clampsUpper: false,
                clampsLower: false,
                suffix: Text("px")
            )

            LuminareSlider(
                "Border thickness",
                value: $previewBorderThickness.doubleBinding,
                in: 0...10,
                format: .number.precision(.fractionLength(0...0)),
                clampsUpper: false,
                clampsLower: false,
                suffix: Text("px")
            )
        }
    }
}
