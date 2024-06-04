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
                    withAnimation(.smooth(duration: 0.25)) {
                        paddingModel.configureScreenPadding = newValue

                        if !paddingModel.configureScreenPadding {
                            paddingModel.window = 0
                            paddingModel.top = 0
                            paddingModel.bottom = 0
                            paddingModel.right = 0
                            paddingModel.left = 0
                        }
                    }
                }
            ),
            columns: 2,
            roundBottom: false
        ) { item in
            Text(item ? "Custom" : "Simple")
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
            sliderRange: 0...100,
            suffix: "px",
            lowerClamp: true
        )
    }

    func screenSidesPaddingConfiguration() -> some View {
        Group {
            LuminareValueAdjuster(
                "Top",
                value: $paddingModel.top,
                sliderRange: 0...100,
                suffix: "px",
                lowerClamp: true,
                controlSize: .compact
            )
            LuminareValueAdjuster(
                "Bottom",
                value: $paddingModel.bottom,
                sliderRange: 0...100,
                suffix: "px",
                lowerClamp: true,
                controlSize: .compact
            )
            LuminareValueAdjuster(
                "Right",
                value: $paddingModel.right,
                sliderRange: 0...100,
                suffix: "px",
                lowerClamp: true,
                controlSize: .compact
            )
            LuminareValueAdjuster(
                "Left",
                value: $paddingModel.left,
                sliderRange: 0...100,
                suffix: "px",
                lowerClamp: true,
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
