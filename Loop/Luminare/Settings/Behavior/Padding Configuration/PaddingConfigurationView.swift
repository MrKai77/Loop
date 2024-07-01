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
    @State var paddingModel = Defaults[.padding]
    @Binding var isPresented: Bool

    let range: ClosedRange<CGFloat> = 0...200

    var body: some View {
        Group {
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
            .buttonStyle(LuminareCompactButtonStyle())
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
                    withAnimation(LuminareSettingsWindow.animation) {
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
            columns: 2,
            roundBottom: false
        ) { custom in
            HStack(spacing: 6) {
                if custom {
                    Image(._18PxSliders)
                    Text("Custom")
                } else {
                    Image(._18PxShapeSquare)
                    Text("Simple")
                }
            }
            .fixedSize()
        }
    }

    func nonScreenPaddingConfiguration() -> some View {
        LuminareValueAdjuster(
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
            sliderRange: range,
            suffix: "px",
            lowerClamp: true,
            upperClamp: true
        )
    }

    func screenSidesPaddingConfiguration() -> some View {
        Group {
            LuminareValueAdjuster(
                "Top",
                value: $paddingModel.top,
                sliderRange: range,
                suffix: "px",
                lowerClamp: true,
                upperClamp: true,
                controlSize: .compact
            )
            LuminareValueAdjuster(
                "Bottom",
                value: $paddingModel.bottom,
                sliderRange: range,
                suffix: "px",
                lowerClamp: true,
                upperClamp: true,
                controlSize: .compact
            )
            LuminareValueAdjuster(
                "Right",
                value: $paddingModel.right,
                sliderRange: range,
                suffix: "px",
                lowerClamp: true,
                upperClamp: true,
                controlSize: .compact
            )
            LuminareValueAdjuster(
                "Left",
                value: $paddingModel.left,
                sliderRange: range,
                suffix: "px",
                lowerClamp: true,
                upperClamp: true,
                controlSize: .compact
            )
        }
    }

    func screenInsetsPaddingConfiguration() -> some View {
        Group {
            LuminareValueAdjuster(
                "Window gaps",
                value: $paddingModel.window,
                sliderRange: 0...100,
                suffix: "px",
                lowerClamp: true
            )
            LuminareValueAdjuster(
                "External bar",
                info: .init("Use this if you are using a custom menubar."),
                value: $paddingModel.externalBar,
                sliderRange: 0...100,
                suffix: "px",
                lowerClamp: true
            )
        }
    }
}
