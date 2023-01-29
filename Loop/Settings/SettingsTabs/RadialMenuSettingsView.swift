//
//  RadialMenuSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-25.
//

import SwiftUI
import Defaults

struct RadialMenuSettingsView: View {
    
    @Default(.loopRadialMenuCornerRadius) var loopRadialMenuCornerRadius
    @Default(.loopRadialMenuThickness) var loopRadialMenuThickness
    @Default(.loopRadialMenuTrigger) var loopRadialMenuTrigger
    
    @State private var selectedLoopTrigger = "􀆪 Function"
    let loopTriggerKeyOptions = [
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
                    Rectangle()
                        .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
                        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
                        .cornerRadius(5)
                    
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
                    
                    RadialMenuView(previewMode: true, timer: Timer.publish(every: 1, on: .main, in: .common).autoconnect())
                }
                .frame(height: 150)
                
                ZStack {
                    Rectangle()
                        .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
                        .background(.secondary.opacity(0.05))
                        .cornerRadius(5)
                    
                    VStack {
                        HStack {
                            Text("Corner Radius")
                            Spacer()
                            
                            HStack {
                                Text("0")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Slider(
                                    value: self.$loopRadialMenuCornerRadius,
                                    in: 0...50,
                                    step: 5
                                )
                                
                                Text("50")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                                    .foregroundColor(.secondary)
                                Slider(
                                    value: self.$loopRadialMenuThickness,
                                    in: 10...34,
                                    step: 2
                                )
                                
                                Text("35")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 230)
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .frame(height: 76)
                
                ZStack {
                    Rectangle()
                        .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
                        .background(.secondary.opacity(0.05))
                        .cornerRadius(5)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("Trigger Loop")
                            Spacer()
                            Picker("", selection: $selectedLoopTrigger) {
                                ForEach(Array(loopTriggerKeyOptions.keys), id: \.self) {
                                    Text($0)
                                }
                            }
                            .frame(width: 160)
                        }
                        Text("To use caps lock, remap it to control in System Settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .onAppear {
                        for dictEntry in loopTriggerKeyOptions {
                            if (dictEntry.value == self.loopRadialMenuTrigger) {
                                self.selectedLoopTrigger = dictEntry.key
                            }
                        }
                    }
                    .onChange(of: self.selectedLoopTrigger) { _ in
                        for dictEntry in loopTriggerKeyOptions {
                            if (dictEntry.key == self.selectedLoopTrigger) {
                                self.loopRadialMenuTrigger = dictEntry.value
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
