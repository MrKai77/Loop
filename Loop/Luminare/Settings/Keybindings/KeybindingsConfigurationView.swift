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
                HStack {
                    KeybindingItemView(keybind: keybind)
                }
            }
        )
        .onChange(of: self.keybinds) { _ in
            Defaults[.keybinds] = self.keybinds
        }
    }
}

struct KeybindingItemView: View {
    @Binding var keybind: WindowAction

    var body: some View {
        directionPicker(selection: $keybind.direction)
    }

    func directionPicker(selection: Binding<WindowDirection>) -> some View {
        Menu(content: {
            directionPickerList
        }, label: {
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
        })
        .fixedSize()
    }

    var directionPickerList: some View {
        Group {
            Picker("General", selection: $keybind.direction) {
                ForEach(WindowDirection.general) { direction in
                    directionPickerItem(direction)
                }
            }
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
    }

    func directionPickerItem(_ direction: WindowDirection) -> some View {
        HStack {
            direction.icon
            Text(direction.name)
        }
        .tag(direction)
    }
}
