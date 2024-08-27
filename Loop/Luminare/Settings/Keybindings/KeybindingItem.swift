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

    let sections: [PickerSection] = [
        .init("General", WindowDirection.general),
        .init("Halves", WindowDirection.halves),
        .init("Quarters", WindowDirection.quarters),
        .init("Horizontal Thirds", WindowDirection.horizontalThirds),
        .init("Vertical Thirds", WindowDirection.verticalThirds),
        .init("Screen Switching", WindowDirection.screenSwitching),
        .init("Size Adjustment", WindowDirection.sizeAdjustment),
        .init("Shrink", WindowDirection.shrink),
        .init("Grow", WindowDirection.grow),
        .init("Move", WindowDirection.move)
    ]

    var moreSection: PickerSection<WindowDirection> {
        if cycleIndex != nil { // If this is a cycling keybind
            .init("More", [WindowDirection.custom])
        } else {
            .init("More", [WindowDirection.custom, WindowDirection.cycle])
        }
    }

    var sectionItems: [WindowDirection] {
        var result: [WindowDirection] = []

        for sectionItems in sections.map(\.items) {
            result.append(contentsOf: sectionItems)
        }

        return result
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
            CustomTextField($searchText)
                .padding(PopoverPanel.contentPadding * 2)

            Divider()

            PickerView(
                Binding(
                    get: {
                        keybind.direction
                    },
                    set: {
                        keybind.direction = $0
                    }
                ),
                $searchResults,
                sections + [moreSection]
            ) { item in
                HStack(spacing: 8) {
                    IconView(action: .constant(.init(item)))
                    Text(item.name)
                }
            }
        }
    }

    func computeSearchResults() {
        withAnimation {
            if searchText.isEmpty {
                searchResults = []
            } else {
                searchResults = sectionItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) } + moreSection.items
            }
        }
    }
}
