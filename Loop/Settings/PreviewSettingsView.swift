//
//  PreviewSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-25.
//

import SwiftUI
import Defaults

struct PreviewSettingsView: View {

    @Default(.previewVisibility) var previewVisibility
    @Default(.previewPadding) var previewPadding
    @Default(.previewCornerRadius) var previewCornerRadius
    @Default(.previewBorderThickness) var previewBorderThickness
    @Default(.animateWindowResizes) var animateWindowResizes

    var body: some View {
        Form {
            Section("Appearance") {
                Toggle(isOn: $previewVisibility) {
                    VStack(alignment: .leading) {
                        Text("Show Preview when looping")

                        if !previewVisibility {
                            VStack(alignment: .leading) {
                                Text("Adjusts window frame in real-time as you choose a direction.")

                                if self.animateWindowResizes {
                                    Text("Windows will not animate their resizes.")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                ZStack {
                    VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                        .ignoresSafeArea()
                        .padding(-10)

                    PreviewView(previewMode: true)
                }
            }
            .frame(height: 150)
            .opacity(previewVisibility ? 1 : 0.5)

            Section {
                CrispValueAdjuster(
                    "Padding",
                    value: $previewPadding,
                    sliderRange: 0...20,
                    postscript: "px",
                    lowerClamp: true
                )
                CrispValueAdjuster(
                    "Corner Radius",
                    value: $previewCornerRadius,
                    sliderRange: 0...20,
                    postscript: "px",
                    lowerClamp: true
                )
                CrispValueAdjuster(
                    "Border Thickness",
                    value: $previewBorderThickness,
                    sliderRange: 0...10,
                    postscript: "px",
                    lowerClamp: true
                )
            }
            .disabled(!previewVisibility)
            .foregroundColor(!previewVisibility ? .secondary : nil)
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
