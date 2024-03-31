//
//  PaddingConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-02-01.
//

import SwiftUI

struct PaddingConfigurationView: View {
    @Binding var isSheetShown: Bool
    @Binding var paddingModel: PaddingModel

    var body: some View {
        VStack {
            Form {
                Section("Padding") {
                    Toggle("Custom screen padding", isOn: $paddingModel.configureScreenPadding)
                }

                Section(content: {
                    ZStack {
                        WallpaperView().equatable()
                        PaddingPreviewView($paddingModel)
                    }
                    .ignoresSafeArea()
                    .padding(-10)
                    .aspectRatio(16/10, contentMode: .fit)
                }, footer: {
                    HStack {
                        Text("This preview is not to scale.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                })

                if paddingModel.configureScreenPadding {
                    Section {
                        CrispValueAdjuster(
                            .init(localized: .init("Crisp Value Adjuster: Window Gaps", defaultValue: "Window gaps")),
                            value: $paddingModel.window,
                            sliderRange: 0...100,
                            postscript: .init(localized: .init("px", defaultValue: "px")),
                            lowerClamp: true
                        )
                        CrispValueAdjuster(
                            .init(localized: .init("Crisp Value Adjuster: External Bar", defaultValue: "External bar")),
                            description: .init(
                                localized: .init(
                                    "Crisp Value Adjuster: External Bar Description",
                                    defaultValue: "Use this if you are using a custom menubar."
                                )
                            ),
                            value: $paddingModel.externalBar,
                            sliderRange: 0...100,
                            postscript: .init(localized: .init("px", defaultValue: "px")),
                            lowerClamp: true
                        )
                    }

                    Section("Screen Padding") {
                        CrispValueAdjuster(
                            .init(localized: .init("Crisp Value Adjuster: Top", defaultValue: "Top")),
                            value: $paddingModel.top,
                            sliderRange: 0...100,
                            postscript: .init(localized: .init("px", defaultValue: "px")),
                            lowerClamp: true
                        )
                        CrispValueAdjuster(
                            .init(localized: .init("Crisp Value Adjuster: Bottom", defaultValue: "Bottom")),
                            value: $paddingModel.bottom,
                            sliderRange: 0...100,
                            postscript: .init(localized: .init("px", defaultValue: "px")),
                            lowerClamp: true
                        )
                        CrispValueAdjuster(
                            .init(localized: .init("Crisp Value Adjuster: Right", defaultValue: "Right")),
                            value: $paddingModel.right,
                            sliderRange: 0...100,
                            postscript: .init(localized: .init("px", defaultValue: "px")),
                            lowerClamp: true
                        )
                        CrispValueAdjuster(
                            .init(localized: .init("Crisp Value Adjuster: Left", defaultValue: "Left")),
                            value: $paddingModel.left,
                            sliderRange: 0...100,
                            postscript: .init(localized: .init("px", defaultValue: "px")),
                            lowerClamp: true
                        )
                    }
                } else {
                    CrispValueAdjuster(
                        .init(localized: .init("Crisp Value Adjuster: Padding", defaultValue: "Padding")),
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
                        postscript: .init(localized: .init("px", defaultValue: "px")),
                        lowerClamp: true
                    )
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .onChange(of: paddingModel.configureScreenPadding) { _ in
                if !paddingModel.configureScreenPadding {
                    paddingModel.top = paddingModel.window
                    paddingModel.externalBar = 0
                    paddingModel.bottom = paddingModel.window
                    paddingModel.right = paddingModel.window
                    paddingModel.left = paddingModel.window
                }
            }

            HStack {
                Button {
                    isSheetShown = false
                } label: {
                    Text("Done")
                }
                .controlSize(.large)
            }
            .offset(y: -14)
        }
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .background(.background)
    }
}
