//
//  CustomCyclingKeybindView.swift
//  Loop
//
//  Created by Kai Azim on 2023-12-27.
//

import SwiftUI

struct CustomCyclingKeybindView: View {
    @Binding var action: WindowAction
    @Binding var isSheetShown: Bool

    @FocusState private var focusedField: String?

    @State var cycleDirections: [WindowAction] = []
    @State private var selection: WindowAction?

    var body: some View {
        VStack {
            Form {
                Section {
                    TextField("Name", text: $action.name.bound, prompt: Text("Custom Cycle"))
                        .focused($focusedField, equals: "name")
                }

                Section {
                    VStack(spacing: 0) {
                        if !self.cycleDirections.isEmpty {
                            List(selection: $selection) {
                                ForEach(self.$cycleDirections) { cycleAction in
                                    CustomCyclingKeybindItemView(action: cycleAction, total: self.$cycleDirections)
                                        .contextMenu {
                                            Button {
                                                self.cycleDirections.removeAll(where: {
                                                    $0 == cycleAction.wrappedValue
                                                })
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .tag(cycleAction.wrappedValue)
                                }
                                .onMove { indices, newOffset in
                                    self.cycleDirections.move(fromOffsets: indices, toOffset: newOffset)
                                }
                            }
                            .listStyle(.bordered(alternatesRowBackgrounds: true))
                        } else {
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
                        }

                        Divider()
                            .foregroundStyle(.primary)

                        Rectangle()
                            .frame(height: 20)
                            .foregroundStyle(.quinary)
                            .overlay {
                                HStack(spacing: 5) {
                                    Menu(content: {
                                        newDirectionMenu()
                                    }, label: {
                                        Image(systemName: "plus")
                                            .foregroundStyle(.secondary)
                                            .contentShape(Rectangle())
                                    })

                                    Divider()
                                        .foregroundStyle(.primary)

                                    Button {
                                        self.cycleDirections.removeAll(where: {
                                            $0 == selection
                                        })
                                    } label: {
                                        Image(systemName: "minus")
                                            .foregroundStyle(.secondary)
                                            .contentShape(Rectangle())
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
                }
            }
            .onTapGesture {
                focusedField = nil
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            HStack {
                Button {
                    isSheetShown = false
                } label: {
                    Text("Done")
                }
                .controlSize(.large)
            }
            .offset(y: -14)
        }
        .frame(width: 450)
        .fixedSize(horizontal: false, vertical: true)

        .onAppear {
            self.cycleDirections = self.action.cycle ?? []
        }
        .onChange(of: self.cycleDirections) { _ in
            if self.cycleDirections.isEmpty {
                self.action.cycle = nil
            } else {
                self.action.cycle = self.cycleDirections
            }
        }
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

        Menu("More") {
            ForEach(WindowDirection.more) { direction in
                if direction != .cycle {
                    newDirectionButton(direction)
                }
            }
        }
    }

    @ViewBuilder
    func newDirectionButton(_ direction: WindowDirection) -> some View {
        Button(action: {
            self.cycleDirections.append(WindowAction(direction, keybind: []))
        }, label: {
            HStack {
                direction.icon
                Text(direction.name)
            }
        })
    }
}
