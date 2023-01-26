//
//  PreviewSettingsView.swift
//  Snapper
//
//  Created by Kai Azim on 2023-01-25.
//

import SwiftUI
import Defaults

struct PreviewSettingsView: View {
    
    @Default(.snapperUsesSystemAccentColor) var snapperUsesSystemAccentColor
    @Default(.snapperAccentColor) var snapperAccentColor
    
    @Default(.showPreviewWhenSnapping) var showPreviewWhenSnapping
    @Default(.snapperPreviewPadding) var snapperPreviewPadding
    @Default(.snapperPreviewCornerRadius) var snapperPreviewCornerRadius
    @Default(.snapperPreviewBorderThickness) var snapperPreviewBorderThickness
    
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
                        Text("Show Preview when snapping")
                        Spacer()
                        
                        Toggle("", isOn: $showPreviewWhenSnapping)
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
                        
                        ZStack {
                            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                                .mask(RoundedRectangle(cornerRadius: self.snapperPreviewCornerRadius).foregroundColor(.white))
                                .shadow(radius: 10)
                            
                            RoundedRectangle(cornerRadius: self.snapperPreviewCornerRadius)
                                .stroke(self.snapperUsesSystemAccentColor ? Color.accentColor : self.snapperAccentColor, lineWidth: self.snapperPreviewBorderThickness)
                        }
                        .padding(self.snapperPreviewPadding + self.snapperPreviewBorderThickness/2)
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
                                        value: self.$snapperPreviewPadding,
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
                                        value: self.$snapperPreviewCornerRadius,
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
                                        value: self.$snapperPreviewBorderThickness,
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
                .disabled(!self.showPreviewWhenSnapping)
                .opacity(!self.showPreviewWhenSnapping ? 0.5 : 1)
            }
        }
        .padding(20)
    }
}
