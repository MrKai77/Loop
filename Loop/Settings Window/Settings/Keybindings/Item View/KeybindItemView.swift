//
//  KeybindItemView.swift
//  Loop
//
//  Created by Kai Azim on 2024-05-03.
//

import Defaults
import Luminare
import SwiftUI

struct KeybindItemView: View {
    @Environment(\.luminareItemBeingHovered) private var isHovering
    @Environment(\.luminareAnimation) var luminareAnimation

    @Default(.triggerKey) private var triggerKey
    @Default(.keybinds) private var keybinds
    @Binding private var action: WindowAction

    @State private var isConfiguringCustom: Bool = false
    @State private var isConfiguringCycle: Bool = false
    private let cycleIndex: Int?
    @State private var isPickerPresented = false

    init(_ keybind: Binding<WindowAction>, cycleIndex: Int? = nil) {
        self._action = keybind
        self.cycleIndex = cycleIndex
    }

    /// Checks if there are any existing keybinds with the same key combination
    private var hasDuplicateKeybinds: Bool {
        keybinds
            .count { $0.keybind == action.keybind } > 1
    }

    var body: some View {
        ZStack {
            titleAndButtons
                .frame(maxWidth: .infinity, alignment: .leading)

            keybindCombination
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .animation(luminareAnimation, value: action)
        .padding(.horizontal, 12)
        .onChange(of: isHovering) { _ in
            if !isHovering {
                isPickerPresented = false
            }
        }
        .onChange(of: action.direction) { _ in
            if action.direction.isCustomizable {
                isConfiguringCustom = true
            }
            if action.direction == .cycle {
                isConfiguringCycle = true
            }
        }
    }

    private var titleAndButtons: some View {
        HStack {
            label()

            HStack {
                if action.direction.isCustomizable {
                    Button(action: {
                        isConfiguringCustom = true
                    }, label: {
                        Image(.ruler)
                    })
                    .buttonStyle(.plain)
                    .luminareModalWithPredefinedSheetStyle(isPresented: $isConfiguringCustom, isCompact: false) {
                        if action.direction == .custom {
                            CustomActionConfigurationView(action: $action, isPresented: $isConfiguringCustom)
                                .frame(width: 400)
                        } else {
                            StashActionConfigurationView(action: $action, isPresented: $isConfiguringCustom)
                                .frame(width: 400)
                        }
                    }
                    .help("Customize this keybind's custom frame.")
                }

                if action.direction == .cycle {
                    Button(action: {
                        isConfiguringCycle = true
                    }, label: {
                        Image(.repeat4)
                    })
                    .buttonStyle(.plain)
                    .luminareModalWithPredefinedSheetStyle(isPresented: $isConfiguringCycle, isCompact: false) {
                        CycleActionConfigurationView(action: $action, isPresented: $isConfiguringCycle)
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
                    .luminarePopup(isPresented: $isPickerPresented, alignment: .leadingLastTextBaseline) {
                        DirectionPickerView(
                            direction: $action.direction,
                            isInCycle: cycleIndex != nil
                        )
                    }
                    .luminareSheetClosesOnDefocus(true)
            }
        }
    }

    private var keybindCombination: some View {
        HStack {
            if let cycleIndex {
                Text("\(cycleIndex)")
                    .frame(width: 27, height: 27)
                    .modifier(LuminareBorderedModifier())
            } else {
                HStack(spacing: 6) {
                    if hasDuplicateKeybinds {
                        keycorderSection(hasConflicts: true)
                            .padding(.leading, 4)
                            .luminarePopover(attachedTo: .topLeading) {
                                Text("There are other keybinds that conflict with this key combination.")
                                    .padding(6)
                            }
                            .luminareTint(overridingWith: .red)
                    } else {
                        keycorderSection(hasConflicts: false)
                    }
                }
                .fixedSize()
            }
        }
    }

    private func label() -> some View {
        Button {
            isPickerPresented.toggle()
        } label: {
            HStack(spacing: 8) {
                IconView(action: action)
                    .equatable()

                if let info = action.direction.infoText {
                    Text(action.getName())
                        .lineLimit(1)
                        .padding(.trailing, 4)
                        .luminarePopover(attachedTo: .topTrailing) {
                            Text(info)
                                .padding(6)
                        }
                        .luminareTint(overridingWith: .yellow)
                } else {
                    Text(action.getName())
                        .lineLimit(1)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(OpenDirectionPickerButtonStyle())
        .help("Customize this keybind's action.")
    }

    private func directionPicker() -> some View {
        VStack {
            Button {
                isPickerPresented.toggle()
            } label: {
                Image(.pen2)
                    .padding(.vertical, 5) // Increase hitbox size
                    .contentShape(.rect)
                    .padding(.vertical, -5) // So that the picker dropdown doesn't get offsetted by the hitbox
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    private func keycorderSection(hasConflicts: Bool) -> some View {
        HStack(spacing: 6) {
            HStack {
                ForEach(triggerKey.sorted().compactMap(\.modifierSystemImage), id: \.self) { image in
                    Text("\(Image(systemName: image))")
                }
            }
            .font(.callout)
            .padding(6)
            .frame(height: 27)
            .modifier(LuminareBorderedModifier())

            Image(systemName: "plus")

            Keycorder($action)
                .opacity(hasConflicts ? 0.5 : 1)
        }
    }
}
