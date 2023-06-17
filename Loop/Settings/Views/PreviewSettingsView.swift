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
                PreviewView(previewMode: true)
            }
            .frame(height: 150)
            
            Section {
                Slider(value: $previewPadding, in: 0...20, step: 2, minimumValueLabel: Text("0%"), maximumValueLabel: Text("100%")) {
                    Text("Padding")
                }
                Slider(value: $previewCornerRadius, in: 0...20, step: 2, minimumValueLabel: Text("0%"), maximumValueLabel: Text("100%")) {
                    Text("Corner Radius")
                }
                Slider(value: $previewBorderThickness, in: 0...10, step: 1, minimumValueLabel: Text("0%"), maximumValueLabel: Text("100%")) {
                    Text("Border Thickness")
                }
            }
            .disabled(!previewVisibility)
            .foregroundColor(!previewVisibility ? .secondary : nil)
        }
        .formStyle(.grouped)
    }
}


//                VStack(spacing: 10) {
//
//                    // Loop's preview window preview
//                    ZStack {
//                        RoundedRectangle(cornerRadius: 5)
//                            .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
//                            .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
//                            .clipShape(RoundedRectangle(cornerRadius: 5))
//
//                        ZStack {    // Grid Background
//                            VStack {
//                                Spacer()
//                                ForEach(1...10, id: \.self) {_ in
//                                    Divider()
//                                    Spacer()
//                                }
//                            }
//
//                            HStack {
//                                Spacer()
//                                ForEach(1...27, id: \.self) {_ in
//                                    Divider()
//                                    Spacer()
//                                }
//                            }
//                        }
//
//                        PreviewView(previewMode: true)
//                            .padding(.horizontal, 30)
//                    }
//                    .frame(height: 150)
