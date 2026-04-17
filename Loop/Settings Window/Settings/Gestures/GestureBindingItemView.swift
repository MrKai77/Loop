//
//  GestureBindingItemView.swift
//  Loop
//
//  Created by Kai Azim on 2026-04-16.
//

import Defaults
import Luminare
import SwiftUI

struct GestureBindingItemView: View {
    @Environment(\.luminareItemBeingHovered) private var isHovering
    @Environment(\.luminareAnimation) var luminareAnimation

    @Default(.keybinds) private var keybinds

    @State private var binding: GestureBinding
    @Binding private var externalBinding: GestureBinding
    private let hasConflict: Bool

    @State private var isActionPickerPresented = false
    @State private var isGestureConfigPresented = false
    @State private var isConfiguringCustom = false
    @State private var isConfiguringCycle = false

    init(_ binding: Binding<GestureBinding>, hasConflict: Bool = false) {
        self.binding = binding.wrappedValue
        self._externalBinding = binding
        self.hasConflict = hasConflict
    }

    var body: some View {
        ZStack {
            gestureConfiguration
                .frame(maxWidth: .infinity, alignment: .leading)

            label
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .onChange(of: binding) { externalBinding = $0 }
    }

    private var label: some View {
        actionIndicator
            .background(alignment: .trailing) {
                if isHovering || isActionPickerPresented {
                    Color.clear
                        .frame(width: 300 - 24)
                        .luminarePopover(
                            isPresented: $isActionPickerPresented,
                            arrowEdge: .top,
                            shouldHideAnchor: true,
                            shouldAnimate: false
                        ) {
                            RadialMenuActionPickerView(selection: actionTypeBinding)
                                .frame(width: 300, height: 300)
                        }
                        .luminareSheetClosesOnDefocus(true)
                        .onChange(of: isActionPickerPresented) { _ in
                            if !isActionPickerPresented {
                                PickerListEventMonitorManager.shared.removeAllMonitors()
                            }
                        }
                }
            }
    }

    var actionIndicator: some View {
        HStack(spacing: 2) {
            if case .radialMenuActions = binding.action {
                HStack(spacing: 4) {
                    Image(.loop)
                    Text("Open Radial Menu")
                }
                .padding(.horizontal, 4)
                .foregroundStyle(.secondary)
            } else {
                Button {
                    isActionPickerPresented = true
                } label: {
                    HStack(spacing: 8) {
                        if let action = resolvedAction {
                            IconView(action: action)

                            Text(action.getName())
                                .fontWeight(.regular)
                                .lineLimit(1)
                        } else {
                            Image(systemName: "bolt.horizontal.fill")
                                .foregroundStyle(.secondary)

                            Text("No Action")
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
            }

            Group {
                if let resolvedAction {
                    if resolvedAction.direction.isCustomizable {
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
                            if resolvedAction.direction == .custom {
                                CustomActionConfigurationView(
                                    action: actionBinding,
                                    isPresented: $isConfiguringCustom
                                )
                                .frame(width: 400)
                            } else {
                                StashActionConfigurationView(
                                    action: actionBinding,
                                    isPresented: $isConfiguringCustom
                                )
                                .frame(width: 400)
                            }
                        }
                        .help("Customize this action's custom frame.")
                    }

                    if resolvedAction.direction == .cycle {
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
                                action: actionBinding,
                                isPresented: $isConfiguringCycle
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

    private var gestureConfiguration: some View {
        Button {
            isGestureConfigPresented = true
        } label: {
            Text(gestureConfigurationText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .luminarePlateau()
        .luminareRoundingBehavior(top: true, bottom: true)
        .padding(.trailing, 4)
        .luminareToolTip(attachedTo: .topTrailing, hidden: !hasConflict) {
            Text("This gesture conflicts with another binding.")
                .padding(6)
        }
        .luminareTint(overridingWith: .red)
        .background(alignment: .leading) {
            if isHovering || isGestureConfigPresented {
                Color.clear
                    .frame(width: 270 - 24)
                    .luminarePopover(
                        isPresented: $isGestureConfigPresented,
                        arrowEdge: .top,
                        shouldHideAnchor: true,
                        shouldAnimate: false
                    ) {
                        GestureConfigPopoverView(binding: $binding)
                            .frame(width: 270)
                    }
                    .luminareSheetClosesOnDefocus(true)
            }
        }
    }

    private var gestureConfigurationText: String {
        switch binding.gestureType {
        case .radialMenu:
            "\(binding.fingerCount)-finger Gesture"
        default:
            "\(binding.fingerCount)-finger \(binding.gestureType.displayName)"
        }
    }

    private var resolvedAction: WindowAction? {
        switch binding.action {
        case .radialMenuActions:
            nil
        case let .singleAction(actionType):
            actionType.resolvedAction
        }
    }

    private var actionTypeBinding: Binding<RadialMenuAction.ActionType> {
        Binding(
            get: {
                if case let .singleAction(actionType) = binding.action {
                    return actionType
                }
                return .custom(.init(.noAction))
            },
            set: { newValue in
                binding.action = .singleAction(newValue)
            }
        )
    }

    private var actionBinding: Binding<WindowAction> {
        Binding(
            get: {
                resolvedAction ?? .init(.noAction)
            },
            set: { newAction in
                if case let .singleAction(actionType) = binding.action {
                    switch actionType {
                    case .custom:
                        binding.action = .singleAction(.custom(newAction))
                    case let .keybindReference(id):
                        if let index = Defaults[.keybinds].firstIndex(where: { $0.id == id }) {
                            keybinds[index] = newAction
                        }
                    }
                }
            }
        )
    }
}
