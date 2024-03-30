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
                    Toggle("Custom Screen Padding", isOn: $paddingModel.configureScreenPadding)
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
                            "Window Gaps",
                            value: $paddingModel.window,
                            sliderRange: 0...100,
                            postscript: String(localized: "px", comment: "The short form of 'pixels'"),
                            lowerClamp: true
                        )
                        CrispValueAdjuster(
                            "External Bar",
                            description: "Use this if you are using a custom menubar.",
                            value: $paddingModel.externalBar,
                            sliderRange: 0...100,
                            postscript: String(localized: "px", comment: "The short form of 'pixels'"),
                            lowerClamp: true
                        )
                    }

                    Section("Screen Padding") {
                        CrispValueAdjuster(
                            "Top",
                            value: $paddingModel.top,
                            sliderRange: 0...100,
                            postscript: String(localized: "px", comment: "The short form of 'pixels'"),
                            lowerClamp: true
                        )
                        CrispValueAdjuster(
                            "Bottom",
                            value: $paddingModel.bottom,
                            sliderRange: 0...100,
                            postscript: String(localized: "px", comment: "The short form of 'pixels'"),
                            lowerClamp: true
                        )
                        CrispValueAdjuster(
                            "Right",
                            value: $paddingModel.right,
                            sliderRange: 0...100,
                            postscript: String(localized: "px", comment: "The short form of 'pixels'"),
                            lowerClamp: true
                        )
                        CrispValueAdjuster(
                            "Left",
                            value: $paddingModel.left,
                            sliderRange: 0...100,
                            postscript: String(localized: "px", comment: "The short form of 'pixels'"),
                            lowerClamp: true
                        )
                    }
                } else {
                    CrispValueAdjuster(
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
                        postscript: String(localized: "px", comment: "The short form of 'pixels'"),
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
