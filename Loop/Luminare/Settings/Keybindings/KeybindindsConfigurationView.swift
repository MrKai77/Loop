//
//  KeybindingsConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-20.
//

import SwiftUI
import Luminare
import Defaults

struct KeybindingsConfigurationView: View {
    @Default(.triggerKey) var triggerKey
    @Default(.triggerDelay) var triggerDelay
    @Default(.doubleClickToTrigger) var doubleClickToTrigger
    @Default(.middleClickTriggersLoop) var middleClickTriggersLoop

    @StateObject private var keycorderModel = KeycorderModel()

    @State var keybinds = Defaults[.keybinds]
    @State private var selectedKeybinds = Set<WindowAction>()

    var body: some View {
        LuminareSection("Trigger Key", noBorder: true) {
            HStack {
                TriggerKeycorder($triggerKey)
                    .environmentObject(keycorderModel)

                Spacer()

                Button("Change") {
                    print("change trigger key")
                }
                .buttonStyle(LuminareCompactButtonStyle())
                .fixedSize()
            }
        }

        LuminareSection("Settings") {
            LuminareValueAdjuster(
                "Trigger delay",
                value: $triggerDelay,
                sliderRange: 0...1,
                suffix: "s",
                lowerClamp: true,
                decimalPlaces: 1
            )

            LuminareToggle("Double-click to trigger", isOn: $doubleClickToTrigger)
            LuminareToggle("Middle-click to trigger", isOn: $middleClickTriggersLoop)
        }

        LuminareList(
            "Keybinds",
            items: $keybinds,
            selection: $selectedKeybinds,
            addAction: { self.keybinds.insert(.init(.noAction), at: 0) },
            content: { keybind in
                //                HStack {
                //                    if let name = keybind.direction.name! {
                //                Text(keybind.id.uuidString)
                //                    }
                KeybindingItemView(keybind)
                //                }
            }
        )
        .onChange(of: self.keybinds) { _ in
            Defaults[.keybinds] = self.keybinds
        }
    }
}

struct KeybindingItemView: View {
    @Binding var keybind: WindowAction

    init(_ keybind: Binding<WindowAction>) {
        self._keybind = keybind
    }

    var body: some View {
        HStack {
            WindowDirectionPicker(keybind: $keybind)
                .equatable()
                .fixedSize()

            Spacer()
        }
        .padding(.leading, 12)
        .formStyle(.grouped)
    }
}

struct WindowDirectionPicker: View, Equatable {
    @Environment(\.hoveringOverLuminareListItem) var isHovering
    @Binding var keybind: WindowAction

    var body: some View {
        Menu {
            // This increases performance!
            if isHovering {
                Picker("Halves", selection: $keybind.direction) {
                    ForEach(WindowDirection.halves) { direction in
                        directionPickerItem(direction)
                    }
                }

                Picker("Quarters", selection: $keybind.direction) {
                    ForEach(WindowDirection.quarters) { direction in
                        directionPickerItem(direction)
                    }
                }

                Picker("Horizontal Thirds", selection: $keybind.direction) {
                    ForEach(WindowDirection.horizontalThirds) { direction in
                        directionPickerItem(direction)
                    }
                }

                Picker("Vertical Thirds", selection: $keybind.direction) {
                    ForEach(WindowDirection.verticalThirds) { direction in
                        directionPickerItem(direction)
                    }
                }

                Picker("Screen Switching", selection: $keybind.direction) {
                    ForEach(WindowDirection.screenSwitching) { direction in
                        directionPickerItem(direction)
                    }
                }

                Picker("Grow/Shrink", selection: $keybind.direction) {
                    ForEach(WindowDirection.sizeAdjustment) { direction in
                        directionPickerItem(direction)
                    }
                    Divider()
                    ForEach(WindowDirection.shrink) { direction in
                        directionPickerItem(direction)
                    }
                    Divider()
                    ForEach(WindowDirection.grow) { direction in
                        directionPickerItem(direction)
                    }
                }

                Picker("More", selection: $keybind.direction) {
                    ForEach(WindowDirection.more) { direction in
                        directionPickerItem(direction)
                    }
                }
            }
        } label: {
            label()
        }
        .menuStyle(.borderlessButton)

        // Removes arrow at trailing end. Hacky, but works for now :3
        .mask {
            HStack(spacing: 0) {
                Color.white

                Rectangle()
                    .frame(width: 15)
                    .foregroundStyle(isHovering ? .white : .clear)
            }
        }
    }

    func directionPickerItem(_ direction: WindowDirection) -> some View {
        HStack {
            direction.icon
            Text(direction.name)
        }
        .tag(direction)
    }

    func label() -> some View {
        HStack {
            keybind.direction.icon

            if keybind.direction == .custom {
                Text(keybind.name ?? .init(localized: .init("Custom Keybind", defaultValue: "Custom Keybind")))
            } else if keybind.direction == .cycle {
                Text(keybind.name ?? .init(localized: .init("Custom Cycle", defaultValue: "Custom Cycle")))
            } else {
                Text(keybind.direction.name)
            }
        }
    }

    static func == (lhs: WindowDirectionPicker, rhs: WindowDirectionPicker) -> Bool {
        lhs.keybind == rhs.keybind
    }
}
