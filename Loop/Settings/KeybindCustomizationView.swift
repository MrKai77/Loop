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

    var body: some View {
        Section {
            HStack {
                Menu(content: {
                    Picker("General", selection: $keybind.direction) {
                        ForEach(WindowDirection.general) { direction in
                            HStack {
                                direction.menuBarImage
                                Text(direction.name)
                            }
                            .tag(direction)
                        }
                    }

                    Picker("Halves", selection: $keybind.direction) {
                        ForEach(WindowDirection.halves) { direction in
                            HStack {
                                direction.menuBarImage
                                Text(direction.name)
                            }
                            .tag(direction)
                        }
                    }

                    Picker("Quarters", selection: $keybind.direction) {
                        ForEach(WindowDirection.quarters) { direction in
                            HStack {
                                direction.menuBarImage
                                Text(direction.name)
                            }
                            .tag(direction)

                        }
                    }

                    Picker("Horizontal Thirds", selection: $keybind.direction) {
                        ForEach(WindowDirection.horizontalThirds) { direction in
                            HStack {
                                direction.menuBarImage
                                Text(direction.name)
                            }
                            .tag(direction)
                        }
                    }

                    Picker("Vertical Thirds", selection: $keybind.direction) {
                        ForEach(WindowDirection.verticalThirds) { direction in
                            HStack {
                                direction.menuBarImage
                                Text(direction.name)
                            }
                            .tag(direction)
                        }
                    }
                }, label: {
                    HStack {
                        keybind.direction.menuBarImage
                        Text(keybind.direction.name)
                    }
                })
                .pickerStyle(InlinePickerStyle())
                .fixedSize()

                Spacer()

                Keycorder(key: $keybind.keybind)
            }
            .padding(.leading, -2)
            .padding(.trailing, -5)
            .padding(.vertical, -10)
            .offset(y: 0.5)
        }
    }
}
