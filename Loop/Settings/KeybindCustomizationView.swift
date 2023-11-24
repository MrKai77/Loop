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
    @Binding var triggerKey: Set<CGKeyCode>

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(.white.opacity(0.00001))

            HStack {
                directionPicker(selection: $keybind.direction)

                Spacer()

                Group {
                    if let systemImages = self.triggerKey.systemImages {
                        ForEach(systemImages, id: \.self) { imageName in
                            Text("\(Image(systemName: imageName))")
                                .foregroundStyle(.secondary)
                                .fontDesign(.monospaced)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .aspectRatio(1, contentMode: .fill)
                                .padding(5)
                                .background {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .foregroundStyle(.background.opacity(0.8))
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(.tertiary.opacity(0.5), lineWidth: 1)
                                    }
                                    .opacity(0.8)
                                }
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    Image(systemName: "plus")
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)

                    Keycorder($keybind)
                }
            }
        }
        .padding(.vertical, 5)
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
