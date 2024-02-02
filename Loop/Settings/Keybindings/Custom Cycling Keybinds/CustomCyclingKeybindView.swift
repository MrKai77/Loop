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
                        if self.cycleDirections.isEmpty {
                            HStack {
                                Spacer()
                                VStack {
                                    Text("Nothing to Cycle Through")
                                        .font(.title3)
                                    Text("Press + to add a cycle item!")
                                        .font(.caption)
                                }
                                Spacer()
                            }
                            .foregroundStyle(.secondary)
                            .padding()
                        } else {
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
                                        self.cycleDirections.removeAll(where: {
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
        .background(.background)

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

        Menu("Screen Switching") {
            ForEach(WindowDirection.screenSwitching) { direction in
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
