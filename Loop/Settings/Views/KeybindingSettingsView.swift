//
//  KeybindingSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Defaults

struct KeybindingSettingsView: View {

    @Default(.triggerKey) var triggerKey
    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.accentColor) var accentColor

    let loopTriggerKeyOptions = LoopTriggerKeys.options

    // This is just a placeholder, but it's a valid image
    @State var triggerKeySymbol: String = "custom.globe.rectangle.fill"

    var body: some View {
        Form {
            Section("Keybindings") {
                VStack(alignment: .leading) {
                    Picker("Trigger Loop", selection: $triggerKey) {
                        ForEach(0..<loopTriggerKeyOptions.count, id: \.self) { idx in
                            HStack {
                                Image(systemName: loopTriggerKeyOptions[idx].symbol)
                                Text(loopTriggerKeyOptions[idx].description)
                            }
                            .tag(loopTriggerKeyOptions[idx].keycode)
                        }
                    }
                    if triggerKey == loopTriggerKeyOptions[1].keycode {
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
                        Text("You can also use the enter key!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack {
                        Image(triggerKeySymbol)
                            .font(Font.system(size: 30, weight: .regular))

                        Image(systemName: "plus")
                            .font(Font.system(size: 15, weight: .bold))

                        Image("custom.space.rectangle.fill")
                            .font(Font.system(size: 30, weight: .regular))
                            .frame(width: 60)
                    }
                    .foregroundStyle(useSystemAccentColor ? Color.accentColor : accentColor)
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Use arrow keys to resize into halves:")
                        Group {
                            Text("Press two keys to for to resize into quarters!")
                            Text("Tip: You can also use WASD keys!")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack {
                        Image(triggerKeySymbol)
                            .font(Font.system(size: 30, weight: .regular))

                        Image(systemName: "plus")
                            .font(Font.system(size: 15, weight: .bold))

                        Image("arrowkeys.up.filled")
                            .font(Font.system(size: 30, weight: .regular))
                            .frame(width: 60)
                    }
                    .foregroundStyle(useSystemAccentColor ? Color.accentColor : accentColor)
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Use JKL to resize into thirds:")

                        Text("Use U and O keys for 2/3-sized windows!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack {
                        Image(triggerKeySymbol)
                            .font(Font.system(size: 30, weight: .regular))

                        Image(systemName: "plus")
                            .font(Font.system(size: 15, weight: .bold))

                        Image(systemName: "j.square.fill")
                            .font(Font.system(size: 30, weight: .regular))
                            .frame(width: 60)
                    }
                    .foregroundStyle(useSystemAccentColor ? Color.accentColor : accentColor)
                }
            }
            .symbolRenderingMode(.hierarchical)
        }
        .formStyle(.grouped)
    }

    func refreshTriggerKeySymbol() {
        var trigger: LoopTriggerKeys = loopTriggerKeyOptions[0]
        for loopTriggerKey in loopTriggerKeyOptions where loopTriggerKey.keycode == triggerKey {
            trigger = loopTriggerKey
        }
        self.triggerKeySymbol = trigger.keySymbol
    }
}
