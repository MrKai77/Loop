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

            Button("Close") {
                isPresented = false
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
            suffix: Text("px")
        )
    }

    func screenSidesPaddingConfiguration() -> some View {
        Group {
            LuminareSlider(
                "Top",
                value: $paddingModel.top.doubleBinding,
                in: range,
                format: .number.precision(.fractionLength(0...0)),
                clampsUpper: false,
                suffix: Text("px")
            )
            .luminareComposeStyle(.inline)

            LuminareSlider(
                "Bottom",
                value: $paddingModel.bottom.doubleBinding,
                in: range,
                format: .number.precision(.fractionLength(0...0)),
                clampsUpper: false,
                suffix: Text("px")
            )
            .luminareComposeStyle(.inline)

            LuminareSlider(
                "Right",
                value: $paddingModel.right.doubleBinding,
                in: range,
                format: .number.precision(.fractionLength(0...0)),
                clampsUpper: false,
                suffix: Text("px")
            )
            .luminareComposeStyle(.inline)

            LuminareSlider(
                "Left",
                value: $paddingModel.left.doubleBinding,
                in: range,
                format: .number.precision(.fractionLength(0...0)),
                clampsUpper: false,
                suffix: Text("px")
            )
            .luminareComposeStyle(.inline)
        }
    }

    func screenInsetsPaddingConfiguration() -> some View {
        Group {
            LuminareSlider(
                "Window gaps",
                value: $paddingModel.window.doubleBinding,
                in: 0...100,
                format: .number.precision(.fractionLength(0...0)),
                clampsUpper: false,
                suffix: Text("px")
            )

            LuminareSlider(
                value: $paddingModel.externalBar.doubleBinding,
                in: 0...100,
                format: .number.precision(.fractionLength(0...3)),
                suffix: Text("px")
            ) {
                Text("External bar")
                    .padding(.trailing, 4)
                    .luminarePopover(attachedTo: .topTrailing) {
                        Text("Use this if you are using a custom menubar.")
                            .padding(6)
                    }
            }
        }
    }
}
