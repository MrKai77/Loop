//
//  KeybindingSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Defaults

struct loopTriggerOptions {
    var symbol: String
    var description: String
    var keycode: UInt16
}

struct KeybindingSettingsView: View {
    
    @Default(.triggerKey) var triggerKey
    
    let LoopTriggerKeyOptions = [
        loopTriggerOptions(symbol: "globe", description: "Globe", keycode: KeyCode.function),
        loopTriggerOptions(symbol: "control", description: "Right Control", keycode: KeyCode.rightControl),
        loopTriggerOptions(symbol: "option", description: "Right Option", keycode: KeyCode.rightOption),
        loopTriggerOptions(symbol: "command", description: "Right Command", keycode: KeyCode.rightCommand),
    ]
    
    var body: some View {
        Form {
            Section("Keybindings") {
                VStack(alignment: .leading) {
                    Picker("Trigger Loop", selection: $triggerKey) {
                        ForEach(0..<LoopTriggerKeyOptions.count, id: \.self) { i in
                            HStack {
                                Image(systemName: LoopTriggerKeyOptions[i].symbol)
                                Text(LoopTriggerKeyOptions[i].description)
                            }
                            .tag(LoopTriggerKeyOptions[i].keycode)
                        }
                    }
                    if triggerKey == LoopTriggerKeyOptions[1].keycode {
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
