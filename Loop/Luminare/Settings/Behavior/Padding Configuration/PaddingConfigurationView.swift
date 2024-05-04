//
//  PaddingConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import SwiftUI
import Luminare
import Defaults

struct PaddingConfigurationView: View {
    @State var paddingModel = Defaults[.padding]
    @Binding var isPresented: Bool

    var body: some View {
        ScreenView {
            PaddingPreviewView($paddingModel)
        }

        .onChange(of: self.paddingModel) { _ in
            // This fixes some weird animations.
            Defaults[.padding] = self.paddingModel
        }

        LuminareSection {
            LuminarePicker(
                elements: [false, true],
                selection: Binding(
                    get: {
                        paddingModel.configureScreenPadding
                    },
                    set: { newValue in
                        withAnimation(.smooth(duration: 0.3)) {
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

            if !paddingModel.configureScreenPadding {
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
            } else {
                LuminareValueAdjuster(
                    "Top",
                    value: $paddingModel.top,
                    sliderRange: 0...100,
                    suffix: .init(localized: .init("px", defaultValue: "px")),
                    lowerClamp: true,
                    controlSize: .compact
                )
                LuminareValueAdjuster(
                    "Bottom",
                    value: $paddingModel.bottom,
                    sliderRange: 0...100,
                    suffix: .init(localized: .init("px", defaultValue: "px")),
                    lowerClamp: true,
                    controlSize: .compact
                )
                LuminareValueAdjuster(
                    "Right",
                    value: $paddingModel.right,
                    sliderRange: 0...100,
                    suffix: .init(localized: .init("px", defaultValue: "px")),
                    lowerClamp: true,
                    controlSize: .compact
                )
                LuminareValueAdjuster(
                    "Left",
                    value: $paddingModel.left,
                    sliderRange: 0...100,
                    suffix: .init(localized: .init("px", defaultValue: "px")),
                    lowerClamp: true,
                    controlSize: .compact
                )
            }
        }

        if paddingModel.configureScreenPadding {
            LuminareSection {
                LuminareValueAdjuster(
                    "Window gaps",
                    value: $paddingModel.window,
                    sliderRange: 0...100,
                    suffix: .init(localized: .init("px", defaultValue: "px")),
                    lowerClamp: true
                )
                LuminareValueAdjuster(
                    "External bar",
                    description: .init(
                        localized: .init(
                            "Crisp Value Adjuster: External Bar Description",
                            defaultValue: "Use this if you are using a custom menubar."
                        )
                    ),
                    value: $paddingModel.externalBar,
                    sliderRange: 0...100,
                    suffix: .init(localized: .init("px", defaultValue: "px")),
                    lowerClamp: true
                )
            }
        }

        Button("Close") {
            isPresented = false
        }
        .buttonStyle(LuminareCompactButtonStyle())
    }
}
