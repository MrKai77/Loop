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

    @State private var action: WindowAction
    @Binding private var boundAction: WindowAction

    @State private var isConfiguringCustom: Bool = false
    @State private var isConfiguringCycle: Bool = false
    private let cycleIndex: Int?
    @State private var isDirectionPickerPresented = false

    init(_ action: Binding<WindowAction>, cycleIndex: Int? = nil) {
        self.action = action.wrappedValue
        self._boundAction = action
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

        .padding(.horizontal, 12)
        .onChange(of: isHovering) { _ in
            if !isHovering {
                isDirectionPickerPresented = false
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
        .onChange(of: action) { boundAction = $0 }
    }

    private var titleAndButtons: some View {
        HStack(spacing: 2) {
            label()

            Group {
                if action.direction.isCustomizable {
                    Button {
                        isConfiguringCustom = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(.plain)
                    .luminareModalWithPredefinedSheetStyle(
                        isPresented: $isConfiguringCustom,
                        isCompact: false
                    ) {
                        if action.direction == .custom {
                            CustomActionConfigurationView(
                                action: $action,
                                isPresented: $isConfiguringCustom
                            )
                            .frame(width: 400)
                        } else {
                            StashActionConfigurationView(
                                action: $action,
                                isPresented: $isConfiguringCustom
                            )
                            .frame(width: 400)
                        }
                    }
                    .help("Customize this action's custom frame.")
                }

                if action.direction == .cycle {
                    Button {
                        isConfiguringCycle = true
                    } label: {
                        Image(systemName: "repeat")
                    }
                    .buttonStyle(.plain)
                    .luminareModalWithPredefinedSheetStyle(
                        isPresented: $isConfiguringCycle,
                        isCompact: false
                    ) {
                        CycleActionConfigurationView(
                            action: $action,
                            isPresented: $isConfiguringCycle
                        )
                        .frame(width: 400)
                    }
                    .help("Customize what this action cycles through.")
                }
            }
            .font(.title3)
            .foregroundStyle(isHovering ? .primary : .secondary)
        }
        .background {
            if isHovering {
                Color.clear
                    .luminarePopup(
                        isPresented: $isDirectionPickerPresented,
                        alignment: .leadingLastTextBaseline
                    ) {
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
                    .luminarePlateau()
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
        .luminareCornerRadius(8)
    }

    private func label() -> some View {
        Button {
            isDirectionPickerPresented.toggle()
        } label: {
            HStack(spacing: 8) {
                IconView(action: action)

                if let info = action.direction.infoText {
                    Text(action.getName())
                        .fontWeight(.regular)
                        .lineLimit(1)
                        .padding(.trailing, 4)
                        .luminarePopover(attachedTo: .topTrailing) {
                            Text(info)
                                .padding(6)
                        }
                        .luminareTint(overridingWith: .yellow)
                } else {
                    Text(action.getName())
                        .fontWeight(.regular)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
        }
        .luminareContentSize(contentMode: .fit, hasFixedHeight: true)
        .luminareRoundingBehavior(top: true, bottom: true)
        .luminareFilledStates([.hovering, .pressed])
        .luminareBorderedStates(.hovering)
        .luminareMinHeight(24)
        .help("Customize this keybind's action.")
        .padding(.leading, -4)
    }

    private func keycorderSection(hasConflicts: Bool) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(triggerKey.sorted().compactMap(\.modifierSystemImage), id: \.self) { image in
                    Text("\(Image(systemName: image))")
                }
            }
            .font(.callout)
            .padding(6)
            .frame(height: 27)
            .luminarePlateau()

            Image(systemName: "plus")
                .foregroundStyle(.secondary)

            Keycorder($action)
                .opacity(hasConflicts ? 0.5 : 1)
        }
    }
}
