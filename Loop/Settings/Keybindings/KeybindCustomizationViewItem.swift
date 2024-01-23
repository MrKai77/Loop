//
//  KeybindCustomizationViewItem.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-31.
//

import SwiftUI
import Defaults

struct KeybindCustomizationViewItem: View {
    @Binding var keybind: WindowAction
    @Binding var triggerKey: Set<CGKeyCode>
    @State var showingInfo: Bool = false
    @State var isConfiguringCustomKeybind: Bool = false
    @State var isConfiguringCyclingKeybind: Bool = false

    var body: some View {
        HStack {
            directionPicker(selection: $keybind.direction)

            if let moreInformation = self.keybind.direction.moreInformation {
                Button(action: {
                    self.showingInfo.toggle()
                }, label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                })
                .buttonStyle(.plain)
                .popover(isPresented: $showingInfo, arrowEdge: .bottom) {
                    Text(moreInformation)
                        .multilineTextAlignment(.center)
                        .padding(8)
                }
            }

            if self.keybind.direction == .custom {
                Button(action: {
                    self.isConfiguringCustomKeybind.toggle()
                }, label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                })
                .buttonStyle(.plain)
                .sheet(isPresented: self.$isConfiguringCustomKeybind) {
                    CustomKeybindView(action: $keybind, isSheetShown: $isConfiguringCustomKeybind)
                }
            }

            if self.keybind.direction == .cycle {
                Button(action: {
                    self.isConfiguringCyclingKeybind.toggle()
                }, label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                })
                .buttonStyle(.plain)
                .sheet(isPresented: self.$isConfiguringCyclingKeybind) {
                    CustomCyclingKeybindView(action: $keybind, isSheetShown: $isConfiguringCyclingKeybind)
                }
            }

            Spacer()

            Group {
                ForEach(self.triggerKey.sorted(), id: \.self) { key in
                    Text("\(Image(systemName: key.systemImage ?? "exclamationmark.circle.fill"))")
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

                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)

                Keycorder($keybind, $triggerKey)
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

                if keybind.direction == .custom {
                    Text(keybind.name ?? "Custom Keybind")
                } else if keybind.direction == .cycle {
                    Text(keybind.name ?? "Custom Cycle")
                } else {
                    Text(keybind.direction.name)
                }

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
