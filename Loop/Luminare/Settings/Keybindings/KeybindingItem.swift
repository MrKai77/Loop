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
        .init(.init(localized: "General"), WindowDirection.general),
        .init(.init(localized: "Halves"), WindowDirection.halves),
        .init(.init(localized: "Quarters"), WindowDirection.quarters),
        .init(.init(localized: "Horizontal Thirds"), WindowDirection.horizontalThirds),
        .init(.init(localized: "Vertical Thirds"), WindowDirection.verticalThirds),
        .init(.init(localized: "Screen Switching"), WindowDirection.screenSwitching),
        .init(.init(localized: "Size Adjustment"), WindowDirection.sizeAdjustment),
        .init(.init(localized: "Shrink"), WindowDirection.shrink),
        .init(.init(localized: "Grow"), WindowDirection.grow),
        .init(.init(localized: "Move"), WindowDirection.move),
        .init(.init(localized: "Go Back"), [WindowDirection.initialFrame, WindowDirection.undo])
    ]

    var moreSection: PickerSection<WindowDirection> {
        if cycleIndex != nil { // If this is a cycling keybind
            .init(.init(localized: "More"), [WindowDirection.custom])
        } else {
            .init(.init(localized: "More"), [WindowDirection.custom, WindowDirection.cycle])
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
                }
                .font(.title3)
                .foregroundStyle(isHovering ? .primary : .secondary)
            }
            .background {
                if isHovering {
                    Color.clear
                        .background(PopoverHolder(isPresented: $isPresented) {
                            directionPickerContents(keybind: $keybind.direction)
                        })
                }
            }

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
        .animation(LuminareSettingsWindow.animation, value: keybind)
        .padding(.horizontal, 12)
        .onAppear {
            computeSearchResults()
        }
        .onChange(of: searchText) { _ in
            computeSearchResults()
        }
        .onChange(of: isHovering) { _ in
            if !isHovering {
                isPresented = false
            }
        }
        .onChange(of: isPresented) { _ in
            searchText = ""
        }
        .onChange(of: keybind.direction) { _ in
            if keybind.direction == .custom {
                isConfiguringCustom = true
            }
            if keybind.direction == .cycle {
                isConfiguringCycle = true
            }
        }
    }

    func label() -> some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    IconView(action: $keybind)

                    Text(keybind.getName())
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }

                if let info = keybind.direction.infoView {
                    info
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(CompactButtonStyle())
        .help("Customize this keybind's action.")
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

    func directionPickerContents(keybind: Binding<WindowDirection>) -> some View {
        VStack(spacing: 0) {
            CustomTextField($searchText)
                .padding(PopoverPanel.contentPadding * 2)

            Divider()

            PickerView(
                keybind,
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

private struct CompactButtonStyle: ButtonStyle {
    @Environment(\.hoveringOverLuminareItem) var hoveringOverLuminareItem
    @Environment(\.isEnabled) private var isEnabled: Bool
    let elementMinHeight: CGFloat = 25
    @State var isHovering: Bool = false
    let cornerRadius: CGFloat = 6

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed || isHovering || hoveringOverLuminareItem {
                    backgroundForState(isPressed: configuration.isPressed)
                        .background {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(.quaternary, lineWidth: 1)
                        }
                        .clipShape(.rect(cornerRadius: cornerRadius))
                        .padding(-4)
                }
            }
            .onHover { isHovering = $0 }
            .animation(LuminareSettingsWindow.fastAnimation, value: [isHovering, hoveringOverLuminareItem])
            .frame(minHeight: elementMinHeight)
            .opacity(isEnabled ? 1 : 0.5)
    }

    private func backgroundForState(isPressed: Bool) -> some View {
        Group {
            if isPressed {
                Rectangle().foregroundStyle(.quaternary)
            } else if isHovering {
                Rectangle().foregroundStyle(.quaternary.opacity(0.6))
            } else {
                Rectangle().foregroundStyle(.quinary.opacity(0.5))
            }
        }
    }
}
