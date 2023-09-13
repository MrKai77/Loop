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
    @Default(.triggerDelay) var triggerDelay
    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.customAccentColor) var customAccentColor

    let loopTriggerKeyOptions = TriggerKey.options
    @State var suggestAddingTriggerDelay: Bool = false

    var body: some View {
        Form {
            Section("Keybindings") {
                VStack(alignment: .leading) {
                    Keycorder("Trigger Key", key: self.$triggerKey, onChange: { event in
                        for key in TriggerKey.options where key.keycode == event.keyCode {
                            return key
                        }
                        return nil
                    })

                    if triggerKey.keycode == .kVK_RightControl {
                        Text("Tip: To use caps lock, remap it to control in System Settings!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: self.triggerKey) { _ in
                    print("\(self.triggerKey.triggerDelayRecommended)")
                    print("\(self.triggerDelay) \(type(of: self.triggerDelay))")
                    if self.triggerKey.triggerDelayRecommended &&
                        self.triggerDelay < 0.1 {
                        self.suggestAddingTriggerDelay.toggle()
                    }
                }
                .alert(
                    "The \(self.triggerKey.name.lowercased()) key is frequently used in other apps.",
                    isPresented: self.$suggestAddingTriggerDelay, actions: {
                        Button("OK") {
                            self.triggerDelay = 0.5
                        }
                        Button("Cancel", role: .cancel) {
                            return
                        }
                    }, message: {
                        Text("Would you like to add a trigger delay? You can always change this later.")
                    })

                HStack {
                    Stepper(
                        "Trigger Delay",
                        value: Binding<Double>(
                            get: { Double(self.triggerDelay) },
                            set: { self.triggerDelay = Float($0) }
                        ),
                        in: 0...1,
                        step: 0.1,
                        format: .number
                    )
                    Text("seconds")
                        .foregroundColor(.secondary)
                }
            }

            Section("Instructions") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Press the spacebar to maximize a window:")
                        Text("Make sure to be pressing your trigger key!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack {
                        Image(self.triggerKey.keySymbol)
                            .font(Font.system(size: 30, weight: .regular))

                        Image(systemName: "plus")
                            .font(Font.system(size: 15, weight: .bold))

                        Image("custom.space.rectangle.fill")
                            .font(Font.system(size: 30, weight: .regular))
                            .frame(width: 60)
                    }
                    .foregroundStyle(Color.accentColor)
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
                        Image(self.triggerKey.keySymbol)
                            .font(Font.system(size: 30, weight: .regular))

                        Image(systemName: "plus")
                            .font(Font.system(size: 15, weight: .bold))

                        Image("arrowkeys.up.filled")
                            .font(Font.system(size: 30, weight: .regular))
                            .frame(width: 60)
                    }
                    .foregroundStyle(Color.accentColor)
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Use JKL to resize into thirds:")
                        Text("Press two keys for 2/3-sized windows!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack {
                        Image(self.triggerKey.keySymbol)
                            .font(Font.system(size: 30, weight: .regular))

                        Image(systemName: "plus")
                            .font(Font.system(size: 15, weight: .bold))

                        Image(systemName: "j.square.fill")
                            .font(Font.system(size: 30, weight: .regular))
                            .frame(width: 60)
                    }
                    .foregroundStyle(Color.accentColor)
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Press return to center a window:")
                        Text("This will not alter the window's current size!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack {
                        Image(self.triggerKey.keySymbol)
                            .font(Font.system(size: 30, weight: .regular))

                        Image(systemName: "plus")
                            .font(Font.system(size: 15, weight: .bold))

                        Image("custom.return.rectangle.fill")
                            .font(Font.system(size: 30, weight: .regular))
                            .frame(width: 60)
                    }
                    .foregroundStyle(Color.accentColor)
                }
            }
            .symbolRenderingMode(.hierarchical)
        }
        .formStyle(.grouped)
    }
}
