//
//  RadialMenuActionItemView.swift
//  Loop
//
//  Created by Kai Azim on 2025-12-08.
//

import Defaults
import Luminare
import SwiftUI

struct RadialMenuActionItemView: View {
    @EnvironmentObject private var windowModel: SettingsWindowManager
    @Environment(\.luminareItemBeingHovered) private var isHovering
    @Environment(\.luminareAnimation) var luminareAnimation
    @Default(.radialMenuActions) private var radialMenuActions
    @Default(.keybinds) private var keybinds

    @Binding private var radialMenuAction: RadialMenuWindowAction
    private let moveUp: () -> Void
    private let moveDown: () -> Void

    @State private var isPickerPresented = false
    @State private var isConfiguringCustom: Bool = false
    @State private var isConfiguringCycle: Bool = false

    init(
        _ action: Binding<RadialMenuWindowAction>,
        moveUp: @escaping () -> Void,
        moveDown: @escaping () -> Void
    ) {
        self._radialMenuAction = action
        self.moveUp = moveUp
        self.moveDown = moveDown
    }

    var body: some View {
        HStack(spacing: 12) {
            label

            Spacer()

            if radialMenuAction.isKeybindReference {
                Image(systemName: "keyboard")
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 8) {
                Button(action: moveUp) {
                    Image(systemName: "arrow.up")
                        .frame(width: 27, height: 27)
                        .font(.callout)
                        .contentShape(.rect)
                }
                .luminareContentSize(aspectRatio: 1.0, contentMode: .fit, hasFixedHeight: true)
                .luminareRoundingBehavior(top: true, bottom: true)

                Button(action: moveDown) {
                    Image(systemName: "arrow.down")
                        .frame(width: 27, height: 27)
                        .font(.callout)
                        .contentShape(.rect)
                }
                .luminareContentSize(aspectRatio: 1.0, contentMode: .fit, hasFixedHeight: true)
                .luminareRoundingBehavior(top: true, bottom: true)
            }
        }
        .padding(.horizontal, 12)
        .onChange(of: isHovering) { _ in
            if !isHovering {
                isPickerPresented = false
            }
        }
        .onChange(of: radialMenuAction.resolvedAction) { _ in
            if let resolvedAction = radialMenuAction.resolvedAction {
                if resolvedAction.direction.isCustomizable {
                    isConfiguringCustom = true
                }
                if resolvedAction.direction == .cycle {
                    isConfiguringCycle = true
                }
            }
        }
    }

    @ViewBuilder
    private var label: some View {
        actionIndicator
            .background {
                if isHovering {
                    Color.clear
                        .luminarePopup(
                            isPresented: $isPickerPresented,
                            alignment: .leadingLastTextBaseline
                        ) {
                            RadialMenuActionPickerView(selection: $radialMenuAction)
                        }
                        .luminareSheetClosesOnDefocus(true)
                }
            }
    }

    @ViewBuilder
    var actionIndicator: some View {
        HStack(spacing: 2) {
            Button {
                isPickerPresented = true
            } label: {
                HStack(spacing: 8) {
                    if let action = radialMenuAction.resolvedAction {
                        IconView(action: action)

                        Text(action.getName())
                            .fontWeight(.regular)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "bolt.horizontal.fill")
                            .foregroundStyle(.secondary)

                        Text("Failed to resolve linked keybind")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
            .luminareContentSize(contentMode: .fit, hasFixedHeight: true)
            .luminareRoundingBehavior(top: true, bottom: true)
            .luminareFilledStates([.hovering, .pressed])
            .luminareBorderedStates(.hovering)
            .luminareMinHeight(24)
            .padding(.leading, -4)

            Group {
                if let resolvedAction = radialMenuAction.resolvedAction {
                    let actionBinding = Binding<WindowAction>(
                        get: {
                            resolvedAction
                        },
                        set: { newAction in
                            if radialMenuAction.isKeybindReference {
                                guard let index = radialMenuAction.keybindIndex else {
                                    return
                                }

                                keybinds[index] = newAction
                            } else {
                                radialMenuAction = .custom(newAction)
                            }
                        }
                    )

                    if resolvedAction.direction.isCustomizable {
                        Button {
                            isConfiguringCustom = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .buttonStyle(.plain)
                        .luminareModalWithPredefinedSheetStyle(isPresented: $isConfiguringCustom, isCompact: false) {
                            if resolvedAction.direction == .custom {
                                CustomActionConfigurationView(action: actionBinding, isPresented: $isConfiguringCustom)
                                    .frame(width: 400)
                            } else {
                                StashActionConfigurationView(action: actionBinding, isPresented: $isConfiguringCustom)
                                    .frame(width: 400)
                            }
                        }
                        .help("Customize this keybind's custom frame.")
                    }

                    if resolvedAction.direction == .cycle {
                        Button {
                            isConfiguringCycle = true
                        } label: {
                            Image(systemName: "repeat")
                        }
                        .buttonStyle(.plain)
                        .luminareModalWithPredefinedSheetStyle(isPresented: $isConfiguringCycle, isCompact: false) {
                            CycleActionConfigurationView(action: actionBinding, isPresented: $isConfiguringCycle)
                                .frame(width: 400)
                        }
                        .help("Customize what this action cycles through.")
                    }
                }
            }
            .font(.title3)
            .foregroundStyle(isHovering ? .primary : .secondary)
        }
    }
}
