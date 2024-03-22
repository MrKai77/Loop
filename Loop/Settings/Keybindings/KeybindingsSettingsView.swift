//
//  KeybindingsSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-28.
//

import SwiftUI
import Defaults

struct KeybindingsSettingsView: View {

    @Default(.keybinds) var keybinds
    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.customAccentColor) var customAccentColor

    @Default(.triggerKey) var triggerKey
    @Default(.doubleClickToTrigger) var doubleClickToTrigger
    @Default(.triggerDelay) var triggerDelay
    @Default(.middleClickTriggersLoop) var middleClickTriggersLoop

    @StateObject private var keycorderModel = KeycorderModel()
    @State private var suggestAddingTriggerDelay: Bool = false
    @State private var selection: WindowAction?

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

                    CrispValueAdjuster(
                        "Trigger Delay",
                        value: $triggerDelay,
                        sliderRange: 0...10,
                        postscript: "sec",
                        step: 0.1,
                        lowerClamp: true
                    )

                    Toggle("Double-click trigger key to trigger Loop", isOn: $doubleClickToTrigger)
                    Toggle("Middle-click to trigger Loop", isOn: $middleClickTriggersLoop)
                }

                Section {
                    VStack(spacing: 0) {
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
                        } else {
                            List(selection: $selection) {
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
                        }

                        Divider()

                        Rectangle()
                            .frame(height: 20)
                            .foregroundStyle(.quinary)
                            .overlay {
                                HStack(spacing: 5) {
                                    Menu(content: {
                                        newDirectionMenu()
                                    }, label: {
                                        Rectangle()
                                            .foregroundStyle(.white.opacity(0.00001))
                                            .overlay {
                                                Image(systemName: "plus")
                                                    .font(.footnote)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .aspectRatio(1, contentMode: .fit)
                                            .padding(-5)
                                    })

                                    Divider()

                                    Button {
                                        self.keybinds.removeAll(where: {
                                            $0 == selection
                                        })
                                    } label: {
                                        Rectangle()
                                            .foregroundStyle(.white.opacity(0.00001))
                                            .overlay {
                                                Image(systemName: "minus")
                                                    .font(.footnote)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .aspectRatio(1, contentMode: .fit)
                                            .padding(-5)
                                    }
                                    .disabled(self.selection == nil)

                                    Spacer()
                                }
                                .buttonStyle(.plain)
                                .padding(5)
                            }
                    }
                    .ignoresSafeArea()
                    .padding(-10)
                } header: {
                    Text("Keybinds")
                } footer: {
                    HStack {
                        Button("Import", systemImage: "square.and.arrow.down") {
                            WindowAction.importPrompt()
                        }

                        Button("Export", systemImage: "square.and.arrow.up") {
                            WindowAction.exportPrompt()
                        }

                        Button("Restore Defaults", systemImage: "arrow.counterclockwise") {
                            _keybinds.reset()
                            _triggerKey.reset()
                            _doubleClickToTrigger.reset()
                            _triggerDelay.reset()
                            _middleClickTriggersLoop.reset()
                            keycorderModel.eventMonitor = nil
                        }
                    }
                    .padding(.top, 10)
                }
            }
            .formStyle(.grouped)
        }
        .environmentObject(keycorderModel)
    }

    @ViewBuilder
    func newDirectionMenu() -> some View {
        Menu("General") {
            ForEach(WindowDirection.general) { direction in
                newDirectionButton(direction)
            }
        }

        Menu("Halves") {
            ForEach(WindowDirection.halves) { direction in
                newDirectionButton(direction)
            }
        }

        Menu("Quarters") {
            ForEach(WindowDirection.quarters) { direction in
                newDirectionButton(direction)
            }
        }

        Menu("Horizontal Thirds") {
            ForEach(WindowDirection.horizontalThirds) { direction in
                newDirectionButton(direction)
            }
        }

        Menu("Vertical Thirds") {
            ForEach(WindowDirection.verticalThirds) { direction in
                newDirectionButton(direction)
            }
        }

        Menu("Screen Switching") {
            ForEach(WindowDirection.screenSwitching) { direction in
                newDirectionButton(direction)
            }
        }

        Menu("More") {
            ForEach(WindowDirection.more) { direction in
                newDirectionButton(direction)
            }
        }
    }

    @ViewBuilder
    func newDirectionButton(_ direction: WindowDirection) -> some View {
        Button(action: {
            if direction == .custom {
                self.keybinds.append(
                    WindowAction(
                        .custom,
                        keybind: [],
                        measureSystem: .percentage,
                        anchor: .center,
                        positionMode: .generic,
                        sizeMode: .custom
                    )
                )
            } else {
                self.keybinds.append(WindowAction(direction, keybind: []))
            }
        }, label: {
            HStack {
                direction.icon
                Text(direction.name)
            }
        })
    }
}
