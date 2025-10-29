//
//  PaddingConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import Defaults
import Luminare
import SwiftUI

struct PaddingConfigurationView: View {
    @Environment(\.luminareAnimation) var luminareAnimation

    @State var paddingModel = Defaults[.padding]
    @Binding var isPresented: Bool

    let range: ClosedRange<Double> = 0...200

    var body: some View {
        VStack(spacing: 12) {
            ScreenView {
                PaddingPreviewView($paddingModel)
            }

            LuminareSection {
                paddingMode()

                if !paddingModel.configureScreenPadding {
                    nonScreenPaddingConfiguration()
                } else {
                    screenSidesPaddingConfiguration()
                }
            }

            if paddingModel.configureScreenPadding {
                LuminareSection {
                    screenInsetsPaddingConfiguration()
                }
            }

            Button {
                isPresented = false
            } label: {
                Text("Close", comment: "Label for a button that closes a modal window")
            }
            .luminareAspectRatio(contentMode: .fill)
            .buttonStyle(.luminareCompact)
        }
        .onChange(of: paddingModel) { _ in
            // This fixes some weird animations.
            Defaults[.padding] = paddingModel
        }
    }

    func paddingMode() -> some View {
        LuminarePicker(
            elements: [false, true],
            selection: Binding(
                get: {
                    paddingModel.configureScreenPadding
                },
                set: { newValue in
                    withAnimation(luminareAnimation) {
                        paddingModel.configureScreenPadding = newValue

                        if !paddingModel.configureScreenPadding {
                            if paddingModel.allEqual {
                                let window = paddingModel.window
                                paddingModel.top = window
                                paddingModel.bottom = window
                                paddingModel.right = window
                                paddingModel.left = window
                            } else {
                                paddingModel.window = 0
                                paddingModel.top = 0
                                paddingModel.bottom = 0
                                paddingModel.right = 0
                                paddingModel.left = 0
                            }
                        }
                    }
                }
            ),
            columns: 2
        ) { custom in
            HStack(spacing: 6) {
                if custom {
                    Image(.sliders)
                    Text("Custom")
                } else {
                    Image(.shapeSquare)
                    Text("Simple")
                }
            }
            .fixedSize()
        }
        .luminarePickerRoundedCorner(bottom: .always)
    }

    func nonScreenPaddingConfiguration() -> some View {
        LuminareSlider(
            "Padding",
            value: Binding(
                get: {
                    paddingModel.window
                },
                set: {
                    paddingModel.window = $0
                    paddingModel.top = $0
                    paddingModel.bottom = $0
                    paddingModel.right = $0
                    paddingModel.left = $0
                }
            ),
            in: range,
            format: .number.precision(.fractionLength(0...0)),
            clampsUpper: false,
            suffix: Text("px", comment: "Unit symbol: pixels")
        )
    }

    func screenSidesPaddingConfiguration() -> some View {
        Group {
            LuminareSlider(
                String(localized: "Top", comment: "Label for a slider in Loop’s padding settings"),
                value: $paddingModel.top.doubleBinding,
                in: range,
                format: .number.precision(.fractionLength(0...0)),
                clampsUpper: false,
                suffix: Text("px", comment: "Unit symbol: pixels")
            )
            .luminareComposeStyle(.inline)

            LuminareSlider(
                String(localized: "Bottom", comment: "Label for a slider in Loop’s padding settings"),
                value: $paddingModel.bottom.doubleBinding,
                in: range,
                format: .number.precision(.fractionLength(0...0)),
                clampsUpper: false,
                suffix: Text("px", comment: "Unit symbol: pixels")
            )
            .luminareComposeStyle(.inline)

            LuminareSlider(
                String(localized: "Right", comment: "Label for a slider in Loop’s padding settings"),
                value: $paddingModel.right.doubleBinding,
                in: range,
                format: .number.precision(.fractionLength(0...0)),
                clampsUpper: false,
                suffix: Text("px", comment: "Unit symbol: pixels")
            )
            .luminareComposeStyle(.inline)

            LuminareSlider(
                String(localized: "Left", comment: "Label for a slider in Loop’s padding settings"),
                value: $paddingModel.left.doubleBinding,
                in: range,
                format: .number.precision(.fractionLength(0...0)),
                clampsUpper: false,
                suffix: Text("px", comment: "Unit symbol: pixels")
            )
            .luminareComposeStyle(.inline)
        }
    }

    func screenInsetsPaddingConfiguration() -> some View {
        Group {
            LuminareSlider(
                String(localized: "Window gaps", comment: "Label for a slider in Loop’s padding settings"),
                value: $paddingModel.window.doubleBinding,
                in: 0...100,
                format: .number.precision(.fractionLength(0...0)),
                clampsUpper: false,
                suffix: Text("px", comment: "Unit symbol: pixels")
            )

            LuminareSlider(
                value: $paddingModel.externalBar.doubleBinding,
                in: 0...100,
                format: .number.precision(.fractionLength(0...0)),
                suffix: Text("px", comment: "Unit symbol: pixels")
            ) {
                Text("External bar", comment: "Label for a slider in Loop’s padding settings")
                    .padding(.trailing, 4)
                    .luminarePopover(attachedTo: .topTrailing) {
                        Text("Use this if you are using a custom menubar.")
                            .padding(6)
                    }
            }
        }
    }
}
