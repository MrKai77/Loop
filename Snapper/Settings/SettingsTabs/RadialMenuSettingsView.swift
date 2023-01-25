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
    @Default(.snapperUsesSystemAccentColor) var snapperUsesSystemAccentColor
    @Default(.snapperAccentColor) var snapperAccentColor
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
                        .foregroundColor(Color("Monochrome Inverted").opacity(0.1))
                    
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
                            ForEach(1...29, id: \.self) {_ in
                                Divider()
                                Spacer()
                            }
                        }
                    }
                    
                    RadialMenuView(configureMode: true)
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
                            
                            Text("0")
                                .font(.caption)
                                .opacity(0.5)
                            Slider(
                                value: self.$snapperCornerRadius,
                                in: 0...50,
                                step: 5
                            )
                            .frame(width: 200)
                            
                            Text("50")
                                .font(.caption)
                                .opacity(0.5)
                        }
                        Divider()
                        HStack {
                            Text("Thickness")
                            Spacer()
                            
                            Text("10")
                                .font(.caption)
                                .opacity(0.5)
                            Slider(
                                value: self.$snapperThickness,
                                in: 10...30,
                                step: 2
                            )
                            .frame(width: 200)
                            
                            Text("30")
                                .font(.caption)
                                .opacity(0.5)
                        }
                        Divider()
                        HStack {
                            Text("Follow System Accent Color")
                            Spacer()
                            Toggle("", isOn: self.$snapperUsesSystemAccentColor)
                                .scaleEffect(0.7)
                                .toggleStyle(.switch)
                        }
                        Divider()
                        HStack {
                            Text("Accent Color")
                            Spacer()
                            ColorPicker("", selection: self.$snapperAccentColor, supportsOpacity: false)
                                .disabled(self.snapperUsesSystemAccentColor)
                        }
                        .opacity(self.snapperUsesSystemAccentColor ? 0.5 : 1)
                    }
                    .padding(.horizontal, 10)
                }
                .frame(height: 152)
                
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
                        if (self.selectedSnapperTrigger == "􀆡 Caps Lock") {
                            Text("Remap Caps Lock to Control in System Settings.")
                                .font(.caption)
                                .opacity(0.5)
                        }
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
                .frame(height: self.selectedSnapperTrigger == "􀆡 Caps Lock" ? 65 : 38)
            }
        }
        .padding(20)
    }
}
