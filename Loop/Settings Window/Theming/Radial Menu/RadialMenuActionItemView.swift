//
//  RadialMenuActionItemView.swift
//  Loop
//
//  Created by Kai Azim on 2025-12-08.
//

import Defaults
import Luminare
import SwiftUI

@MainActor
final class RadialMenuWindowActionWrapper: ObservableObject {
    @Published var isConfiguringCustom: Bool = false
    @Published var isConfiguringCycle: Bool = false
    @Published var action: RadialMenuAction {
        didSet { updateBindingAction() }
    }

    private let bindingAction: Binding<RadialMenuAction>

    init(binding action: Binding<RadialMenuAction>) {
        self.action = action.wrappedValue
        self.bindingAction = action
    }

    private func updateBindingAction() {
        guard bindingAction.wrappedValue != action else { return }
        bindingAction.wrappedValue = action

        guard let resolvedAction = action.resolved else {
            isConfiguringCustom = false
            isConfiguringCycle = false
            return
        }

        Task {
            isConfiguringCustom = resolvedAction.direction.isCustomizable
            isConfiguringCycle = resolvedAction.direction == .cycle
        }
    }
}

struct RadialMenuActionItemView: View {
    @EnvironmentObject private var windowModel: SettingsWindowManager
    @Environment(\.luminareItemBeingHovered) private var isHovering
    @Environment(\.luminareAnimation) var luminareAnimation
    @StateObject private var wrapper: RadialMenuWindowActionWrapper

    @Default(.radialMenuActions) private var radialMenuActions
    @Default(.keybinds) private var keybinds

    private let moveUp: () -> ()
    private let moveDown: () -> ()

    @State private var isPickerPresented = false

    init(
        _ action: Binding<RadialMenuAction>,
        moveUp: @escaping () -> (),
        moveDown: @escaping () -> ()
    ) {
        self._wrapper = StateObject(wrappedValue: RadialMenuWindowActionWrapper(binding: action))
        self.moveUp = moveUp
        self.moveDown = moveDown
    }

    var body: some View {
        HStack(spacing: 12) {
            label

            Spacer()

            if wrapper.action.type.isKeybindReference {
                Image(systemName: "keyboard")
                    .foregroundStyle(.secondary)
                    .help("This action is linked to a keybind. Changes made to this action will affect both.")
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
                            RadialMenuActionPickerView(selection: $wrapper.action.type)
                        }
                        .luminareSheetClosesOnDefocus(true)
                        .onChange(of: isPickerPresented) { _ in
                            if !isPickerPresented {
                                PickerListEventMonitorManager.shared.removeAllMonitors()
                            }
                        }
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
                    if let action = wrapper.action.resolved {
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
                if let resolvedAction = wrapper.action.resolved {
                    let actionBinding = Binding<WindowAction>(
                        get: {
                            resolvedAction
                        },
                        set: { newAction in
                            switch wrapper.action.type {
                            case .custom:
                                wrapper.action.type = .custom(newAction)
                            case .keybindReference:
                                guard let index = Defaults[.keybinds].firstIndex(where: { $0.id == wrapper.action.associatedActionId }) else {
                                    return
                                }

                                keybinds[index] = newAction
                            }
                        }
                    )

                    if resolvedAction.direction.isCustomizable {
                        Button {
                            wrapper.isConfiguringCustom = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .buttonStyle(.plain)
                        .luminareModalWithPredefinedSheetStyle(
                            isPresented: $wrapper.isConfiguringCustom,
                            isCompact: false
                        ) {
                            if resolvedAction.direction == .custom {
                                CustomActionConfigurationView(
                                    action: actionBinding,
                                    isPresented: $wrapper.isConfiguringCustom
                                )
                                .frame(width: 400)
                            } else {
                                StashActionConfigurationView(
                                    action: actionBinding,
                                    isPresented: $wrapper.isConfiguringCustom
                                )
                                .frame(width: 400)
                            }
                        }
                        .help("Customize this action's custom frame.")
                    }

                    if resolvedAction.direction == .cycle {
                        Button {
                            wrapper.isConfiguringCycle = true
                        } label: {
                            Image(systemName: "repeat")
                        }
                        .buttonStyle(.plain)
                        .luminareModalWithPredefinedSheetStyle(
                            isPresented: $wrapper.isConfiguringCycle,
                            isCompact: false
                        ) {
                            CycleActionConfigurationView(
                                action: actionBinding,
                                isPresented: $wrapper.isConfiguringCycle
                            )
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
