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
                KeybindingItemView(keybind)
                    .environmentObject(keycorderModel)
            }
        )
        .onChange(of: self.keybinds) { _ in
            Defaults[.keybinds] = keybinds
        }
        .onAppear {
            keybinds = Defaults[.keybinds]
        }
    }
}

struct KeybindingItemView: View {
    @Environment(\.hoveringOverLuminareListItem) var isHovering

    @Default(.triggerKey) var triggerKey
    @Binding var keybind: WindowAction

    @State var isConfiguringCustomKeybind: Bool = false
    @State var isConfiguringCustomCycle: Bool = false

    init(_ keybind: Binding<WindowAction>) {
        self._keybind = keybind
    }

    var body: some View {
        HStack {
//            if keybind.direction == .cycle {
//                Button(action: {
//                    withAnimation(.smooth(duration: 0.3)) {
//                        isConfiguringCustomCycle.toggle()
//                    }
//                }, label: {
//                    Image(systemName: "chevron.right")
//                        .font(.caption2)
//                        .foregroundStyle(isHovering ? .primary : .secondary)
//                        .rotationEffect(.degrees(isConfiguringCustomCycle ? 90 : 0))
//                        .contentShape(.rect)
//                })
//                .buttonStyle(.plain)
//            }

            WindowDirectionPicker(keybind: $keybind)
                .equatable()
                .fixedSize()

            if keybind.direction == .custom {
                Button(action: {
                    isConfiguringCustomKeybind = true
                }, label: {
                    Image(systemName: "pencil")
                        .font(.title3)
                        .foregroundStyle(isHovering ? .primary : .secondary)
                })
                .buttonStyle(.plain)
                .luminareModal(isPresented: $isConfiguringCustomKeybind) {
                    CustomKeybindConfigurationView(action: $keybind, isPresented: $isConfiguringCustomKeybind)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                HStack {
                    ForEach(triggerKey.sorted().compactMap { $0.systemImage }, id: \.self) { image in
                        Text("\(Image(systemName: image))")
                    }
                }
                .font(.callout)
                .padding(6)
                .frame(height: 27)
                .modifier(LuminareBordered())

                Image(systemName: "plus")

                Keycorder($keybind)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
    }
}

struct WindowDirectionPicker: View, Equatable {
    @Environment(\.hoveringOverLuminareListItem) var isHovering
    @Binding var keybind: WindowAction

    var body: some View {
        Menu {
            // This increases performance!
            if isHovering {
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
        } label: {
            label()
                .padding(.vertical, 5) // Increase hitbox size
                .contentShape(.rect)
                .padding(.vertical, -5) // So that the picker dropdown doesn't get offsetted by the hitbox
        }
        .buttonStyle(PlainButtonStyle())    // Override Luminare button styling
    }

    func directionPickerItem(_ direction: WindowDirection) -> some View {
        HStack {
            direction.icon
            Text(direction.name)
        }
        .tag(direction)
    }

    func label() -> some View {
        HStack(spacing: 5) {
            keybind.direction.icon

            if keybind.direction == .custom {
                Text(keybind.name ?? .init(localized: .init("Custom Keybind", defaultValue: "Custom Keybind")))
            } else if keybind.direction == .cycle {
                Text(keybind.name ?? .init(localized: .init("Custom Cycle", defaultValue: "Custom Cycle")))
            } else {
                Text(keybind.direction.name)
            }

//            if isHovering {
//                Image(systemName: "chevron.down")
//                    .font(.caption)
//            }
        }
    }

    static func == (lhs: WindowDirectionPicker, rhs: WindowDirectionPicker) -> Bool {
        lhs.keybind == rhs.keybind
    }
}
