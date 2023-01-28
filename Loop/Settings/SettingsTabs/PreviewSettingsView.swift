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
                        .stroke(Color("Monochrome").opacity(0.2), lineWidth: 0.5)
                    RoundedRectangle(cornerRadius: 5)
                        .foregroundColor(Color("Monochrome").opacity(0.03))
                    
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
                            .stroke(Color("Monochrome").opacity(0.2), lineWidth: 0.5)
                        RoundedRectangle(cornerRadius: 5)
                            .foregroundColor(Color("Monochrome Inverted").opacity(0.25))
                        
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
                            .stroke(Color("Monochrome").opacity(0.2), lineWidth: 0.5)
                        RoundedRectangle(cornerRadius: 5)
                            .foregroundColor(Color("Monochrome").opacity(0.03))
                        
                        VStack {
                            HStack {
                                Text("Padding")
                                Spacer()

                                HStack {
                                    Text("0")
                                        .font(.caption)
                                        .opacity(0.5)
                                    Slider(
                                        value: self.$loopPreviewPadding,
                                        in: 0...20,
                                        step: 2
                                    )

                                    Text("20")
                                        .font(.caption)
                                        .opacity(0.5)
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
                                        .opacity(0.5)
                                    Slider(
                                        value: self.$loopPreviewCornerRadius,
                                        in: 0...20,
                                        step: 2
                                    )
                                    
                                    Text("20")
                                        .font(.caption)
                                        .opacity(0.5)
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
                                        .opacity(0.5)
                                    Slider(
                                        value: self.$loopPreviewBorderThickness,
                                        in: 0...10,
                                        step: 1
                                    )
                                    
                                    Text("10")
                                        .font(.caption)
                                        .opacity(0.5)
                                }
                                .frame(width: 230)
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                    .frame(height: 114)
                }
                .disabled(!self.loopPreviewVisibility)
                .opacity(!self.loopPreviewVisibility ? 0.5 : 1)
            }
        }
        .padding(20)
    }
}
