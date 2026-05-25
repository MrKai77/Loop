//
//  GestureItemView.swift
//  Loop
//
//  Created by Kai Azim on 2026-04-16.
//

import Defaults
import Luminare
import SwiftUI

struct GestureItemView: View {
    @Environment(\.luminareAnimation) var luminareAnimation

    @Default(.keybinds) private var keybinds
    @Default(.gestures) private var gestures

    @State private var gesture: Gesture
    @Binding private var externalGesture: Gesture

    @State private var isActionPickerPresented = false
    @State private var isGestureConfigPresented = false
    @State private var isConfiguringCustom = false
    @State private var isConfiguringCycle = false

    init(_ gesture: Binding<Gesture>) {
        self.gesture = gesture.wrappedValue
        self._externalGesture = gesture
    }

    private var hasConflict: Bool {
        Gesture.conflictingIDs(in: gestures).contains(gesture.id)
    }

    var body: some View {
        ZStack {
            Group {
                if hasConflict {
                    gestureConfiguration
                        .luminareTint(overridingWith: .red)
                } else {
                    gestureConfiguration
                }
            }
            .luminareToolTip(attachedTo: .topLeading, hidden: !hasConflict) {
                Text("There are other gestures that conflict with this gesture.")
                    .padding(6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            actionSelection
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .onChange(of: resolvedAction?.direction) { _ in
            if resolvedAction?.direction.isCustomizable == true {
                isConfiguringCustom = true
            }
            if resolvedAction?.direction == .cycle {
                isConfiguringCycle = true
            }
        }
        .onChange(of: gesture) { externalGesture = $0 }
    }

    private var gestureConfiguration: some View {
        Button {
            isGestureConfigPresented = true
        } label: {
            Text(gestureConfigurationText)
                .fontWeight(.regular)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .contentShape(.rect)
        }
        .luminareContentSize(contentMode: .fit, hasFixedHeight: true)
        .luminareRoundingBehavior(top: true, bottom: true)
        .luminareFilledStates([.hovering, .pressed])
        .luminareBorderedStates(.hovering)
        .luminareMinHeight(24)
        .opacity(hasConflict ? 0.5 : 1)
        .help("Customize this gesture.")
        .padding(.leading, -4)
        .luminarePopover(
            isPresented: $isGestureConfigPresented,
            arrowEdge: .top,
            attachmentAnchor: .topLeading,
            shouldHideAnchor: true,
            shouldAnimate: false
        ) {
            GestureConfigPopoverView(gesture: $gesture)
                .frame(width: 300)
        }
    }

    private var actionSelection: some View {
        actionIndicator
            .luminarePopover(
                isPresented: $isActionPickerPresented,
                arrowEdge: .top,
                attachmentAnchor: .topTrailing,
                shouldHideAnchor: true,
                shouldAnimate: false
            ) {
                RadialMenuActionPickerView(selection: actionTypeBinding)
                    .frame(width: 300, height: 300)
            }
            .onChange(of: isActionPickerPresented) { _ in
                if !isActionPickerPresented {
                    PickerListEventMonitorManager.shared.removeAllMonitors()
                }
            }
    }

    private var actionIndicator: some View {
        HStack(spacing: 2) {
            if case .radialMenuActions = gesture.action {
                HStack(spacing: 4) {
                    Image(.loop)
                    Text("Open Radial Menu")
                        .fontWeight(.regular)
                        .lineLimit(1)
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
                                .fontWeight(.regular)
                                .lineLimit(1)
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
                .help("Customize this gesture's action.")
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
                        .luminareModal(isPresented: $isConfiguringCustom) {
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
                        .luminareModalCornerRadius(24)
                        .help("Customize this action's custom frame.")
                    }

                    if resolvedAction.direction == .cycle {
                        Button {
                            isConfiguringCycle = true
                        } label: {
                            Image(systemName: "repeat")
                        }
                        .buttonStyle(.plain)
                        .luminareModal(isPresented: $isConfiguringCycle) {
                            CycleActionConfigurationView(
                                action: actionBinding,
                                isPresented: $isConfiguringCycle
                            )
                            .frame(width: 400)
                        }
                        .luminareModalCornerRadius(24)
                        .help("Customize what this action cycles through.")
                    }
                }
            }
            .font(.title3)
            .foregroundStyle(.secondary)
        }
    }

    private var gestureConfigurationText: String {
        switch gesture.kind {
        case .radialMenu:
            "\(gesture.fingerCount)-finger Gesture"
        default:
            "\(gesture.fingerCount)-finger \(gesture.kind.displayName)"
        }
    }

    private var resolvedAction: WindowAction? {
        switch gesture.action {
        case .radialMenuActions:
            nil
        case let .singleAction(actionType):
            actionType.resolvedAction
        }
    }

    private var actionTypeBinding: Binding<RadialMenuAction.ActionType> {
        Binding(
            get: {
                if case let .singleAction(actionType) = gesture.action {
                    return actionType
                }
                return .custom(.init(.noAction))
            },
            set: { newValue in
                gesture.action = .singleAction(newValue)
            }
        )
    }

    private var actionBinding: Binding<WindowAction> {
        Binding(
            get: {
                resolvedAction ?? .init(.noAction)
            },
            set: { newAction in
                if case let .singleAction(actionType) = gesture.action {
                    switch actionType {
                    case .custom:
                        gesture.action = .singleAction(.custom(newAction))
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
