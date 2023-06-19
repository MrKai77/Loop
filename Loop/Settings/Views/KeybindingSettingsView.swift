//
//  KeybindingSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Defaults

struct LoopTriggerKeys {
    var symbol: String
    var keySymbol: String
    var description: String
    var keycode: UInt16
    
    static let options: [LoopTriggerKeys] = [
        LoopTriggerKeys(
            symbol: "globe",
            keySymbol: "custom.globe.rectangle.fill",
            description: "Globe",
            keycode: KeyCode.function
        ),
        LoopTriggerKeys(
            symbol: "control",
            keySymbol: "custom.control.rectangle.fill",
            description: "Right Control",
            keycode: KeyCode.rightControl
        ),
        LoopTriggerKeys(
            symbol: "option",
            keySymbol: "custom.option.rectangle.fill",
            description: "Right Option",
            keycode: KeyCode.rightOption
        ),
        LoopTriggerKeys(
            symbol: "command",
            keySymbol: "custom.command.rectangle.fill",
            description: "Right Command",
            keycode: KeyCode.rightCommand
        ),
    ]
}

struct KeybindingSettingsView: View {
    
    @Default(.triggerKey) var triggerKey
    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.accentColor) var accentColor
    
    let LoopTriggerKeyOptions = LoopTriggerKeys.options
    @State var triggerKeySymbol: String = ""
    
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
                .onAppear {
                    refreshTriggerKeySymbol()
                }
                .onChange(of: triggerKey) { _ in
                    refreshTriggerKeySymbol()
                }
            }
            
            Section("Instructions") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Press the spacebar with your trigger\nkey to maximize a window:")
                    }
                    
                    Spacer()
                    
                    Group {
                        Image(triggerKeySymbol)
                            .font(Font.system(size: 30, weight: .regular))
                        
                        Image(systemName: "plus")
                            .font(Font.system(size: 15, weight: .bold))
                        
                        Image("custom.space.rectangle.fill")
                            .font(Font.system(size: 30, weight: .regular))
                    }
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(useSystemAccentColor ? Color.accentColor : accentColor)
                    .backport.symbolEffectPulse()
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Use arrow keys to resize into halves:")
                        Text("Press two keys to for quarters!")
                        
                        Text("Tip: You can also use WASD keys!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Group {
                        Image(triggerKeySymbol)
                            .font(Font.system(size: 30, weight: .regular))
                        
                        Image(systemName: "plus")
                            .font(Font.system(size: 15, weight: .bold))
                        
                        Image(systemName: "arrowkeys.up.filled")
                            .font(Font.system(size: 30, weight: .regular))
                    }
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(useSystemAccentColor ? Color.accentColor : accentColor)
                    .backport.symbolEffectPulse()
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Use JKL to resize into thirds:")
                        
                        Text("Use U and O keys for 2/3-sized windows!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Group {
                        Image(triggerKeySymbol)
                            .font(Font.system(size: 30, weight: .regular))
                        
                        Image(systemName: "plus")
                            .font(Font.system(size: 15, weight: .bold))
                        
                        Image(systemName: "j.square.fill")
                            .font(Font.system(size: 30, weight: .regular))
                    }
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(useSystemAccentColor ? Color.accentColor : accentColor)
                    .backport.symbolEffectPulse()
                }
            }
        }
        .formStyle(.grouped)
    }
    
    func refreshTriggerKeySymbol() {
        var trigger: LoopTriggerKeys = LoopTriggerKeyOptions[0]
        for loopTriggerKey in LoopTriggerKeyOptions {
            if loopTriggerKey.keycode == triggerKey {
                trigger = loopTriggerKey
            }
        }
        self.triggerKeySymbol = trigger.keySymbol
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        KeybindingSettingsView()
            .frame(width: 450)
    }
}


struct Backport<Content> {
    let content: Content
}

extension View {
    var backport: Backport<Self> { Backport(content: self) }
}

extension Backport where Content: View {
    @ViewBuilder func symbolEffectPulse(wholeSymbol: Bool = false) -> some View {
        if #available(macOS 14, *) {
            if wholeSymbol {
                content.symbolEffect(.pulse.wholeSymbol)
            }
            else {
                content.symbolEffect(.pulse)
            }
        } else {
            content
        }
    }
}
