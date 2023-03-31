//
//  RadialMenuSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-25.
//

import SwiftUI
import Defaults

struct loopTriggerOptions {
    var symbol: String
    var description: String
    var keycode: Int
}

struct RadialMenuSettingsView: View {
    
    @Default(.loopRadialMenuCornerRadius) var loopRadialMenuCornerRadius
    @Default(.loopRadialMenuThickness) var loopRadialMenuThickness
    @Default(.loopRadialMenuTrigger) var loopRadialMenuTrigger
    
    let loopTriggerKeyOptions = [
        loopTriggerOptions(symbol: "control", description: "Left Control", keycode: 59),
        loopTriggerOptions(symbol: "option", description: "Left Option", keycode: 58),
        loopTriggerOptions(symbol: "option", description: "Right Option", keycode: 61),
        loopTriggerOptions(symbol: "command", description: "Right Command", keycode: 54),
        loopTriggerOptions(symbol: "capslock", description: "Caps Lock", keycode: 62),
        loopTriggerOptions(symbol: "fn", description: "Function", keycode: 63)
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Behavior")
                .fontWeight(.medium)
            
            VStack(spacing: 10) {
                
                // Loop radial menu preview
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
                    
                    RadialMenuView(previewMode: true, timer: Timer.publish(every: 1, on: .main, in: .common).autoconnect())
                }
                .frame(height: 150)
                
                // Loop appearance settings
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
                        .background(.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    
                    VStack {
                        HStack {
                            Text("Corner Radius")
                            Spacer()
                            
                            HStack {
                                Text("30")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Slider(
                                    value: $loopRadialMenuCornerRadius,
                                    in: 30...50,
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
                                    value: $loopRadialMenuThickness,
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
                
                // Loop trigger key
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
                        .background(.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("Trigger Loop")
                            Spacer()
                            Picker("", selection: $loopRadialMenuTrigger) {
                                ForEach(0..<loopTriggerKeyOptions.count, id: \.self) { i in
                                    HStack {
                                        Image(systemName: loopTriggerKeyOptions[i].symbol)
                                        Text(loopTriggerKeyOptions[i].description)
                                    }
                                    .tag(loopTriggerKeyOptions[i].keycode)
                                }
                            }
                            .frame(width: 160)
                        }
                        Text("To use caps lock, remap it to control in System Settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                }
                .frame(height: 65)
            }
        }
        .padding(20)
    }
}
