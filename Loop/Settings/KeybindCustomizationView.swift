//
//  KeybindCustomizationView.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-31.
//

import SwiftUI
import Defaults

struct KeybindCustomizationViewItem: View {
    @Binding var keybind: Keybind
    @Binding var triggerKey: TriggerKey

    var body: some View {
        Section {
            ZStack {
                Rectangle()
                    .foregroundStyle(.white.opacity(0.00001))

                HStack {
                    directionPicker(selection: $keybind.direction)

                    Spacer()

                    Text("\(Image(systemName: triggerKey.symbol))")
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(1, contentMode: .fill)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .foregroundStyle(.background.opacity(0.8))
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(.tertiary.opacity(0.5), lineWidth: 1)
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .opacity(0.8)

                    Keycorder($keybind)
                }
                .padding(5)
            }
            .padding(.leading, -2)
            .padding(.trailing, -5)
            .padding(.vertical, -10)
            .offset(y: 0.5)
        }
    }

    @ViewBuilder
    func directionPicker(selection: Binding<WindowDirection>) -> some View {
        Menu(content: {
            Picker("General", selection: $keybind.direction) {
                ForEach(WindowDirection.general) { direction in
                    directionPickerItem(direction)
                }
            }

            Picker("Cyclable", selection: $keybind.direction) {
                ForEach(WindowDirection.cyclable) { direction in
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

            Picker("More", selection: $keybind.direction) {
                ForEach(WindowDirection.more) { direction in
                    directionPickerItem(direction)
                }
            }
        }, label: {
            HStack {
                keybind.direction.icon
                Text(keybind.direction.name)
            }
        })
        .fixedSize()
    }

    @ViewBuilder
    func directionPickerItem(_ direction: WindowDirection) -> some View {
        HStack {
            direction.icon
            Text(direction.name)
        }
        .tag(direction)
    }
}
