//
//  CustomCyclingKeybindItemView.swift
//  Loop
//
//  Created by Kai Azim on 2023-12-28.
//

import SwiftUI

struct CustomCyclingKeybindItemView: View {
    @Binding var action: WindowAction
    @Binding var total: [WindowAction]

    @State var isConfiguringCustomKeybind: Bool = false

    var body: some View {
        HStack {
            directionPicker(selection: $action.direction)

            if self.action.direction == .custom {
                Button(action: {
                    self.isConfiguringCustomKeybind.toggle()
                }, label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                })
                .buttonStyle(.plain)
                .sheet(isPresented: self.$isConfiguringCustomKeybind) {
                    CustomKeybindView(action: $action, isSheetShown: $isConfiguringCustomKeybind)
                }
            }
            Spacer()

            Text("\(self.total.firstIndex(of: action) ?? -1)")
                .foregroundStyle(.secondary)
                .fontDesign(.monospaced)
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    func directionPicker(selection: Binding<WindowDirection>) -> some View {
        Menu(content: {
            Picker("General", selection: $action.direction) {
                ForEach(WindowDirection.general) { direction in
                    directionPickerItem(direction)
                }
            }

            Picker("Halves", selection: $action.direction) {
                ForEach(WindowDirection.halves) { direction in
                    directionPickerItem(direction)
                }
            }

            Picker("Quarters", selection: $action.direction) {
                ForEach(WindowDirection.quarters) { direction in
                    directionPickerItem(direction)
                }
            }

            Picker("Horizontal Thirds", selection: $action.direction) {
                ForEach(WindowDirection.horizontalThirds) { direction in
                    directionPickerItem(direction)
                }
            }

            Picker("Vertical Thirds", selection: $action.direction) {
                ForEach(WindowDirection.verticalThirds) { direction in
                    directionPickerItem(direction)
                }
            }

            Picker("More", selection: $action.direction) {
                ForEach(WindowDirection.more) { direction in
                    if direction != .cycle {
                        directionPickerItem(direction)
                    }
                }
            }
        }, label: {
            HStack {
                self.action.direction.icon
                Text(action.direction == .custom ? action.name ?? "Custom Keybind" : action.direction.name)
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
