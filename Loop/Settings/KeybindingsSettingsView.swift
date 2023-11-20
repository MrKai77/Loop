//
//  KeybindingsSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-28.
//

import Foundation

import SwiftUI
import Defaults

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
        Form {
            Section("Trigger Key") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Trigger Key")
                        Spacer()
                        TriggerKeycorder(self.$triggerKey)
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

            Section("Keybinds") {
                VStack(spacing: 0) {
                    List {
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

                                Button("Reset Defaults...") {
                                    keybinds = []
                                    _keybinds.reset()
                                }
                            }
                            .padding(4)
                        }
                }
                .ignoresSafeArea()
                .padding(-10)
            }
        }
        .formStyle(.grouped)
        .frame(maxHeight: 680)
    }
}
