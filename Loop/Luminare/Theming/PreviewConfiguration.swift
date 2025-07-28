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

    @Default(.previewVisibility) var previewVisibility
    @Default(.moveCursorWithWindow) var moveCursorWithWindow
    @Default(.previewPadding) var previewPadding
    @Default(.previewCornerRadius) var previewCornerRadius
    @Default(.previewBorderThickness) var previewBorderThickness

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
                Text("Animate window resize")
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
                clampsUpper: true,
                clampsLower: true,
                suffix: Text("px")
            )

            LuminareSlider(
                "Corner radius",
                value: $previewCornerRadius.doubleBinding,
                in: 0...20,
                format: .number.precision(.fractionLength(0...0)),
                clampsUpper: true,
                clampsLower: true,
                suffix: Text("px")
            )

            LuminareSlider(
                "Border thickness",
                value: $previewBorderThickness.doubleBinding,
                in: 0...10,
                format: .number.precision(.fractionLength(0...0)),
                clampsUpper: true,
                clampsLower: true,
                suffix: Text("px")
            )
        }
    }
}

extension Binding where Value == CGFloat {
    var doubleBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(wrappedValue) },
            set: { wrappedValue = CGFloat($0) }
        )
    }
}
