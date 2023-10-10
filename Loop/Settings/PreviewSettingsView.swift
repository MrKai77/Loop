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

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Show Preview when looping", isOn: $previewVisibility)
            }

            Section {
                PreviewView(previewMode: true, window: nil)
            }
            .frame(height: 150)
            .opacity(previewVisibility ? 1 : 0.5)

            Section {
                Slider(
                    value: $previewPadding,
                    in: 0...20,
                    step: 2,
                    minimumValueLabel: Text("0px"),
                    maximumValueLabel: Text("20px")
                ) {
                    Text("Padding")
                }
                Slider(
                    value: $previewCornerRadius,
                    in: 0...20,
                    step: 2,
                    minimumValueLabel: Text("0px"),
                    maximumValueLabel: Text("20px")
                ) {
                    Text("Corner Radius")
                }
                Slider(
                    value: $previewBorderThickness,
                    in: 0...10,
                    step: 1,
                    minimumValueLabel: Text("0px"),
                    maximumValueLabel: Text("10px")
                ) {
                    Text("Border Thickness")
                }
            }
            .disabled(!previewVisibility)
            .foregroundColor(!previewVisibility ? .secondary : nil)
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
