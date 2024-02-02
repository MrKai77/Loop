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
    @State var useSteppers: Bool = false

    var body: some View {
        VStack {
            Form {
                Section("Padding") {
                    Toggle("Custom Screen Padding", isOn: $paddingModel.configureScreenPadding)
                    Toggle("Use Custom Values", isOn: $useSteppers)
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
                        paddingAdjuster("Window Gaps", value: $paddingModel.window.toDoubleBinding())
                    }

                    Section("Screen Padding") {
                        paddingAdjuster("Top", value: $paddingModel.top.toDoubleBinding())
                        paddingAdjuster("Bottom", value: $paddingModel.bottom.toDoubleBinding())
                        paddingAdjuster("Right", value: $paddingModel.right.toDoubleBinding())
                        paddingAdjuster("Left", value: $paddingModel.left.toDoubleBinding())
                    }
                } else {
                    paddingAdjuster(
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
                        )
                    )
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

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

    @ViewBuilder
    func paddingAdjuster(_ title: String, value: Binding<Double>) -> some View {
        if self.useSteppers {
            paddingStepper(title, value: value)
        } else {
            paddingSlider(title, value: value)
        }
    }

    @ViewBuilder
    func paddingSlider(_ title: String, value: Binding<Double>) -> some View {
        Slider(
            value: value,
            in: 0...50,
            step: 5,
            minimumValueLabel: Text("0px"),
            maximumValueLabel: Text("50px")
        ) {
            Text(title)
        }
    }

    @ViewBuilder
    func paddingStepper(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Stepper(
                title,
                value: value,
                in: 0...100,
                format: .number
            )
            Text("px")
        }
    }
}

extension Binding where Value == CGFloat {
    fileprivate func toDoubleBinding() -> Binding<Double> {
        Binding<Double>(get: {
            Double(self.wrappedValue)
        }, set: {
            self.wrappedValue = CGFloat($0)
        })
    }
}
