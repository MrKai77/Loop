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
    
    let LoopTriggerKeyOptions = [
        loopTriggerOptions(symbol: "globe", description: "Globe", keycode: 63),
        loopTriggerOptions(symbol: "control", description: "Right Control", keycode: 62),
        loopTriggerOptions(symbol: "option", description: "Right Option", keycode: 61),
        loopTriggerOptions(symbol: "command", description: "Right Command", keycode: 54),
    ]
    
    var body: some View {
        Form {
            Section("Behavior") {
                RadialMenuView(frontmostWindow: nil, previewMode: true, timer: Timer.publish(every: 1, on: .main, in: .common).autoconnect())
            }
            
            Section {
                Slider(value: $loopRadialMenuCornerRadius, in: 30...50, step: 4, minimumValueLabel: Text("10%"), maximumValueLabel: Text("100%")) {
                    Text("Corner Radius")
                }
                Slider(value: $loopRadialMenuThickness, in: 10...34, step: 4, minimumValueLabel: Text("10%"), maximumValueLabel: Text("100%")) {
                    Text("Thickness")
                }
            }
            
            Section {
                VStack(alignment: .leading) {
                    Picker("Trigger Loop", selection: $loopRadialMenuTrigger) {
                        ForEach(0..<LoopTriggerKeyOptions.count, id: \.self) { i in
                            HStack {
                                Image(systemName: LoopTriggerKeyOptions[i].symbol)
                                Text(LoopTriggerKeyOptions[i].description)
                            }
                            .tag(LoopTriggerKeyOptions[i].keycode)
                        }
                    }
                    if loopRadialMenuTrigger == LoopTriggerKeyOptions[1].keycode {
                        Text("Tip: To use caps lock, remap it to control in System Settings!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
