//
//  RadialMenuSettingsView.swift
//  Snapper
//
//  Created by Kai Azim on 2023-01-25.
//

import SwiftUI
import Defaults

struct RadialMenuSettingsView: View {
    
    @Default(.snapperCornerRadius) var snapperCornerRadius
    @Default(.snapperThickness) var snapperThickness
    @Default(.snapperTrigger) var snapperTrigger
    
    @State private var selectedSnapperTrigger = "􀆪 Function"
    let snapperTriggerKeyOptions = [
        "􀆍 Left Control": 262401,
        "􀆕 Left Option": 524576,
        "􀆕 Right Option": 524608,
        "􀆔 Right Command": 1048848,
        "􀆡 Caps Lock": 270592,
        "􀆪 Function": 8388864
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Behavior")
                .fontWeight(.medium)
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
                    
                    RadialMenuView(previewMode: true)
                }
                .frame(height: 150)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color("Monochrome").opacity(0.2), lineWidth: 0.5)
                    RoundedRectangle(cornerRadius: 5)
                        .foregroundColor(Color("Monochrome").opacity(0.03))
                    
                    VStack {
                        HStack {
                            Text("Corner Radius")
                            Spacer()
                            
                            HStack {
                                Text("0")
                                    .font(.caption)
                                    .opacity(0.5)
                                Slider(
                                    value: self.$snapperCornerRadius,
                                    in: 0...50,
                                    step: 5
                                )
                                
                                Text("50")
                                    .font(.caption)
                                    .opacity(0.5)
                            }
                            .frame(width: 230)
                        }
                        Divider()
                        HStack {
                            Text("Thickness")
                            Spacer()
                            
                            HStack {
                                Text("10")
                                    .font(.caption)
                                    .opacity(0.5)
                                Slider(
                                    value: self.$snapperThickness,
                                    in: 10...30,
                                    step: 2
                                )
                                
                                Text("30")
                                    .font(.caption)
                                    .opacity(0.5)
                            }
                            .frame(width: 230)
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .frame(height: 76)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color("Monochrome").opacity(0.2), lineWidth: 0.5)
                    RoundedRectangle(cornerRadius: 5)
                        .foregroundColor(Color("Monochrome").opacity(0.03))
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("Trigger Snapper")
                            Spacer()
                            Picker("", selection: $selectedSnapperTrigger) {
                                ForEach(Array(snapperTriggerKeyOptions.keys), id: \.self) {
                                    Text($0)
                                }
                            }
                            .frame(width: 160)
                        }
                        Text("To use caps lock, remap it to control in System Settings.")
                            .font(.caption)
                            .opacity(0.5)
                    }
                    .padding(.horizontal, 10)
                    .onAppear {
                        for dictEntry in snapperTriggerKeyOptions {
                            if (dictEntry.value == self.snapperTrigger) {
                                self.selectedSnapperTrigger = dictEntry.key
                            }
                        }
                    }
                    .onChange(of: self.selectedSnapperTrigger) { _ in
                        for dictEntry in snapperTriggerKeyOptions {
                            if (dictEntry.key == self.selectedSnapperTrigger) {
                                self.snapperTrigger = dictEntry.value
                            }
                        }
                    }
                }
                .frame(height: 65)
            }
        }
        .padding(20)
    }
}
