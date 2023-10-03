//
//  KeybindingSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Defaults

struct KeybindingsSettingsView: View {

    @Default(.triggerKey) var triggerKey
    @Default(.doubleClickToTrigger) var doubleClickToTrigger
    @Default(.triggerDelay) var triggerDelay
    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.customAccentColor) var customAccentColor

    @State var suggestAddingTriggerDelay: Bool = false
    @State var suggestDisablingCapsLock: Bool = false

    var body: some View {
        Form {
            Section("Keybindings") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Trigger Key")
                        Spacer()
                        Keycorder(key: self.$triggerKey) { event in
                            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.capsLock) {
                                self.suggestDisablingCapsLock = true
                                return nil
                            } else {
                                self.suggestDisablingCapsLock = false
                            }

                            for key in TriggerKey.options where key.keycode == event.keyCode {
                                return key
                            }
                            return nil
                        }
                        .popover(isPresented: $suggestDisablingCapsLock, arrowEdge: .bottom, content: {
                            Text("Your Caps Lock key is on! Disable it to correctly assign a key.")
                                .padding(8)
                        })
                    }

                    if triggerKey.keycode == .kVK_RightControl {
                        Text("Tip: To use caps lock, remap it to control in System Settings!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: self.triggerKey) { _ in
                    if self.triggerKey.doubleClickRecommended &&
                        !self.doubleClickToTrigger {
                        self.suggestAddingTriggerDelay.toggle()
                    }
                }
                .alert(
                    "The \(self.triggerKey.name.lowercased()) key is frequently used in other apps.",
                    isPresented: self.$suggestAddingTriggerDelay, actions: {
                        Button("OK") {
                            self.doubleClickToTrigger = true
                        }
                        Button("Cancel", role: .cancel) {
                            return
                        }
                    }, message: {
                        Text("Would you like to enable \"Double-click to trigger Loop\"? "
                           + "You can always change this later.")
                    }
                )

                Toggle("Double-click to trigger Loop", isOn: $doubleClickToTrigger)

                HStack {
                    Stepper(
                        "Trigger Delay (seconds)",
                        value: Binding<Double>(
                            get: { Double(self.triggerDelay) },
                            set: { self.triggerDelay = Float($0) }
                        ),
                        in: 0...1,
                        step: 0.1,
                        format: .number
                    )
                }
            }

            Section("Instructions") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Press the spacebar to maximize a window:")
                        Text("Use the shift key to toggle fullscreen!")
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

                HStack {
                    VStack(alignment: .leading) {
                        Text("Use Z undo window operations:")
                    }

                    Spacer()

                    HStack {
                        Image(self.triggerKey.keySymbol)
                            .font(Font.system(size: 30, weight: .regular))

                        Image(systemName: "plus")
                            .font(Font.system(size: 15, weight: .bold))

                        Image(systemName: "z.square.fill")
                            .font(Font.system(size: 30, weight: .regular))
                            .frame(width: 60)
                    }
                    .foregroundStyle(Color.accentColor)
                }
            }
            .symbolRenderingMode(.hierarchical)
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
