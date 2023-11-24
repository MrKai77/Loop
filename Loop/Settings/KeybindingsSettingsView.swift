//
//  KeybindingsSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-28.
//

import Foundation

import SwiftUI
import Defaults
import Settings

struct KeybindingsSettingsView: View {

    @Default(.keybinds) var keybinds
    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.customAccentColor) var customAccentColor
    @Default(.preferMinimizeWithScrollDown) var preferMinimizeWithScrollDown

    @Default(.triggerKey) var triggerKey
    @Default(.doubleClickToTrigger) var doubleClickToTrigger
    @Default(.triggerDelay) var triggerDelay
    @Default(.middleClickTriggersLoop) var middleClickTriggersLoop

    @State private var suggestAddingTriggerDelay: Bool = false

    var body: some View {
        ZStack {
            Form {
                Section("Trigger Key") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Trigger Key")
                            Spacer()
                            TriggerKeycorder(self.$triggerKey)
                        }

                        if triggerKey == [.kVK_RightControl] {
                            Text("Tip: To use caps lock, remap it to control in System Settings!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

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

                Section("Keybinds") {
                    List {
                        if self.keybinds.isEmpty {
                            HStack {
                                Spacer()
                                VStack {
                                    Text("No Keybinds")
                                        .font(.title3)
                                    Text("Press + to add a keybind!")
                                        .font(.caption)
                                }
                                Spacer()
                            }
                            .foregroundStyle(.secondary)
                            .padding()
                        }
                        ForEach(self.$keybinds) { keybind in
                            KeybindCustomizationViewItem(keybind: keybind, triggerKey: self.$triggerKey)
                                .contextMenu {
                                    Button {
                                        self.keybinds.removeAll(where: { $0 == keybind.wrappedValue })
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .tag(keybind.wrappedValue)
                        }
                        .onMove { indices, newOffset in
                            self.keybinds.move(fromOffsets: indices, toOffset: newOffset)
                        }
                    }
                    .listStyle(.bordered(alternatesRowBackgrounds: true))
                    .ignoresSafeArea()
                    .padding(-10)
                }
            }
            .formStyle(.grouped)
            .padding(.bottom, 30)

            VStack(spacing: 0) {
                Spacer()
                Divider()
                Rectangle()
                    .frame(height: 30)
                    .foregroundStyle(.background)
                    .overlay {
                        HStack {
                            Button("+") {
                                self.keybinds.append(Keybind(.noAction, keycode: []))
                            }

                            Spacer()

                            Button("Restore Defaults", systemImage: "arrow.counterclockwise") {
                                _keybinds.reset()
                                _triggerKey.reset()
                                _doubleClickToTrigger.reset()
                                _triggerDelay.reset()
                                _middleClickTriggersLoop.reset()
                            }
                        }
                        .padding(4)
                    }
            }
        }
        .frame(minHeight: 500, maxHeight: 680)
    }
}
