//
//  KeybindingItem.swift
//  Loop
//
//  Created by Kai Azim on 2024-05-03.
//

import Defaults
import Luminare
import SwiftUI

struct KeybindingItemView: View {
    @Environment(\.hoveringOverLuminareItem) var isHovering

    @Default(.triggerKey) var triggerKey
    @Binding var keybind: WindowAction

    @State var isConfiguringCustom: Bool = false
    @State var isConfiguringCycle: Bool = false

    let cycleIndex: Int?

    init(_ keybind: Binding<WindowAction>, cycleIndex: Int? = nil) {
        self._keybind = keybind
        self.cycleIndex = cycleIndex
    }

    // Keybind selection popover
    @State private var searchText = ""
    @State private var searchResults: [WindowDirection] = []
    @State private var isPresented = false
    @FocusState private var focusedSearchField: Bool?

    let all: [WindowDirection] = WindowDirection.general + WindowDirection.halves + WindowDirection.quarters + WindowDirection.horizontalThirds + WindowDirection.verticalThirds + WindowDirection.screenSwitching + WindowDirection.sizeAdjustment + WindowDirection.shrink + WindowDirection.grow + WindowDirection.move

    var other: [WindowDirection] {
        if cycleIndex != nil { // If this is a cycling keybind
            [.custom]
        } else {
            [.custom, .cycle]
        }
    }

    var body: some View {
        HStack {
            HStack {
                label()
                    .onChange(of: keybind) { _ in
                        if keybind.direction == .custom {
                            isConfiguringCustom = true
                        }
                        if keybind.direction == .cycle {
                            isConfiguringCycle = true
                        }
                    }

                HStack {
                    if keybind.direction == .custom {
                        Button(action: {
                            isConfiguringCustom = true
                        }, label: {
                            Image(._18PxRuler)
                        })
                        .buttonStyle(.plain)
                        .luminareModal(isPresented: $isConfiguringCustom) {
                            CustomActionConfigurationView(action: $keybind, isPresented: $isConfiguringCustom)
                                .frame(width: 400)
                        }
                        .help("Customize this keybind's custom frame.")
                    }

                    if keybind.direction == .cycle {
                        Button(action: {
                            isConfiguringCycle = true
                        }, label: {
                            Image(._18PxRepeat4)
                        })
                        .buttonStyle(.plain)
                        .luminareModal(isPresented: $isConfiguringCycle) {
                            CycleActionConfigurationView(action: $keybind, isPresented: $isConfiguringCycle)
                                .frame(width: 400)
                        }
                        .help("Customize what this keybind cycles through.")
                    }

                    if isHovering {
                        directionPicker()
                            .help("Customize this keybind's action.")
                    }
                }
                .font(.title3)
                .foregroundStyle(isHovering ? .primary : .secondary)
            }
            .background(PopoverHolder(isPresented: $isPresented) {
                directionPickerContents()
            })

            Spacer()

            if let cycleIndex {
                Text("\(cycleIndex)")
                    .frame(width: 27, height: 27)
                    .modifier(LuminareBordered())
            } else {
                HStack(spacing: 6) {
                    HStack {
                        ForEach(triggerKey.sorted().compactMap(\.systemImage), id: \.self) { image in
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
                .fixedSize()
            }
        }
        .padding(.horizontal, 12)
        .onAppear {
            computeSearchResults()
        }
        .onChange(of: searchText) { _ in
            computeSearchResults()
        }
        .onChange(of: isPresented) { _ in
            searchText = ""
        }
    }

    func label() -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                IconView(action: $keybind)

                Text(keybind.getName())
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(LuminareSettingsWindow.animation, value: keybind)
            }

            if let info = keybind.direction.infoView {
                info
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    func directionPicker() -> some View {
        VStack {
            Button {
                isPresented.toggle()
                focusedSearchField = true
            } label: {
                Image(._18PxPen2)
                    .padding(.vertical, 5) // Increase hitbox size
                    .contentShape(.rect)
                    .padding(.vertical, -5) // So that the picker dropdown doesn't get offsetted by the hitbox
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    func directionPickerContents() -> some View {
        VStack(spacing: 0) {
            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
                .padding(PopoverPanel.contentPadding)
                .focused($focusedSearchField, equals: true)

            Divider()

            ScrollView(showsIndicators: false) {
                VStack(spacing: PopoverPanel.sectionPadding) {
                    pickerSection("General", WindowDirection.general)
                    pickerSection("Halves", WindowDirection.halves)
                    pickerSection("Quarters", WindowDirection.quarters)
                    pickerSection("Horizontal Thirds", WindowDirection.horizontalThirds)
                    pickerSection("Vertical Thirds", WindowDirection.verticalThirds)
                    pickerSection("Screens", WindowDirection.screenSwitching)
                    pickerSection("Sizes", WindowDirection.sizeAdjustment)
                    pickerSection("Shrinks", WindowDirection.shrink)
                    pickerSection("Grow", WindowDirection.grow)
                    pickerSection("Moves", WindowDirection.move)
                    pickerSection("Other", other)
                }
                .padding(PopoverPanel.contentPadding)
            }
        }
    }

    func computeSearchResults() {
        withAnimation {
            if searchText.isEmpty {
                searchResults = all + other
            } else {
                searchResults = all.filter { $0.name.localizedCaseInsensitiveContains(searchText) } + other
            }
        }
    }

    func pickerSection(_ title: String, _ items: [WindowDirection]) -> some View {
        PopoverPickerSection(
            title,
            items,
            $searchResults,
            Binding(
                get: {
                    keybind.direction
                },
                set: {
                    keybind.direction = $0
                }
            )
        ) { item in
            Text(item.name)
        }
    }
}
