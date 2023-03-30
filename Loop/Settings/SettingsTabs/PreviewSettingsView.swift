//
//  PreviewSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-25.
//

import SwiftUI
import Defaults

struct PreviewSettingsView: View {
    
    @Default(.loopPreviewVisibility) var loopPreviewVisibility
    @Default(.loopPreviewPadding) var loopPreviewPadding
    @Default(.loopPreviewCornerRadius) var loopPreviewCornerRadius
    @Default(.loopPreviewBorderThickness) var loopPreviewBorderThickness
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Behavior")
                .fontWeight(.medium)
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
                        .background(.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    
                    HStack {
                        Text("Show Preview when looping")
                        Spacer()
                        
                        Toggle("", isOn: $loopPreviewVisibility)
                            .scaleEffect(0.7)
                            .toggleStyle(.switch)
                    }
                    .padding([.horizontal], 10)
                }
                .frame(height: 38)
                
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
                            .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        
                        ZStack {    // Grid Background
                            VStack {
                                Spacer()
                                ForEach(1...10, id: \.self) {_ in
                                    Divider()
                                    Spacer()
                                }
                            }
                            
                            HStack {
                                Spacer()
                                ForEach(1...27, id: \.self) {_ in
                                    Divider()
                                    Spacer()
                                }
                            }
                        }
                        
                        PreviewView(previewMode: true)
                            .padding(.horizontal, 30)
                    }
                    .frame(height: 150)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
                            .background(.secondary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        
                        VStack {
                            HStack {
                                Text("Padding")
                                Spacer()

                                HStack {
                                    Text("0")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Slider(
                                        value: $loopPreviewPadding,
                                        in: 0...20,
                                        step: 2
                                    )

                                    Text("20")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 230)
                            }
                            Divider()
                            HStack {
                                Text("Corner Radius")
                                Spacer()
                                
                                HStack {
                                    Text("0")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Slider(
                                        value: $loopPreviewCornerRadius,
                                        in: 0...20,
                                        step: 2
                                    )
                                    
                                    Text("20")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 230)
                            }
                            Divider()
                            HStack {
                                Text("Border Thickness")
                                Spacer()
                                
                                HStack {
                                    Text("0")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Slider(
                                        value: $loopPreviewBorderThickness,
                                        in: 0...10,
                                        step: 1
                                    )
                                    
                                    Text("10")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 230)
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                    .frame(height: 114)
                }
                .disabled(!loopPreviewVisibility)
                .foregroundColor(!loopPreviewVisibility ? .secondary : nil)
            }
        }
        .padding(20)
    }
}
