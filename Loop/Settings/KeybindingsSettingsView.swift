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
    @Default(.middleClickTriggersLoop) var middleClickTriggersLoop
    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.customAccentColor) var customAccentColor
    @Default(.preferMinimizeWithScrollDown) var preferMinimizeWithScrollDown

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

                Toggle("Double-click trigger key to trigger Loop", isOn: $doubleClickToTrigger)
                Toggle("Middle-click to trigger Loop", isOn: $middleClickTriggersLoop)
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

                    KeyboardShortcutView(triggerKey: self.triggerKey, instructionKey: "space")
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

                    KeyboardShortcutView(triggerKey: self.triggerKey, instructionKey: "arrowkeys.up.filled")
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Use JKL to resize into thirds:")
                        Text("Press two keys for 2/3-sized windows!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    KeyboardShortcutView(triggerKey: self.triggerKey, instructionKey: "J")
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Press return to center a window:")
                        Text("This will not alter the window's current size!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    KeyboardShortcutView(triggerKey: self.triggerKey, instructionKey: "return")
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Press Z undo window operations:")
                    }

                    Spacer()

                    KeyboardShortcutView(triggerKey: self.triggerKey, instructionKey: "Z")
                }

                HStack {
                    VStack(alignment: .leading) {
                        if self.preferMinimizeWithScrollDown {
                            Text("Scroll down to minimize a window:")
                        } else {
                            Text("Scroll down to hide a window:")
                        }
                    }

                    Spacer()

                    KeyboardShortcutView(triggerKey: self.triggerKey, instructionKey: "digitalcrown.arrow.counterclockwise.fill")
                }
            }
            .symbolRenderingMode(.hierarchical)
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

struct KeyboardShortcutView: View {
    
    let triggerKey: TriggerKey
    let instructionKey: String
    
    var body: some View {
        HStack {
            KeycapView(instructionKey: triggerKey.keySymbol)

            Image(systemName: "plus")
                .imageScale(.large)

            KeycapView(instructionKey: instructionKey)
        }
        .foregroundStyle(.tint)
    }
}

struct KeycapView: View {
    
    let instructionKey: String
    
    var body: some View {
        Group {
            if(instructionKey.count > 1) {
                Image(systemName: instructionKey)
                    .font(.system(size: 17, weight: .regular))
            } else {
                Text(instructionKey)
                    .font(.system(size: 17, weight: .light, design: .rounded))
            }
        }
        .frame(width: 40, height: 36)
        .background()
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .primary.opacity(0.1), radius: 0, x: 0, y: 3)
    }
}
