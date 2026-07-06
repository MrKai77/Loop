//
//  GestureConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2026-04-16.
//

import Luminare
import SwiftUI

struct GestureConfigurationView: View {
    @Environment(\.luminareAnimation) private var luminareAnimation

    @State private var gesture: GestureBinding
    @Binding private var externalGesture: GestureBinding
    @Binding private var isPresented: Bool

    init(gesture: Binding<GestureBinding>, isPresented: Binding<Bool>) {
        self.gesture = gesture.wrappedValue
        self._externalGesture = gesture
        self._isPresented = isPresented
    }

    private var kindBinding: Binding<GestureBinding.Kind> {
        Binding(
            get: { gesture.kind },
            set: { newKind in
                let oldKind = gesture.kind
                gesture.kind = newKind

                if newKind == .radialMenu {
                    gesture.action = .radialMenuActions
                } else if oldKind == .radialMenu {
                    gesture.action = .singleAction(.custom(.init(.noAction)))
                }
            }
        )
    }

    private var tabBinding: Binding<GestureTab> {
        Binding(
            get: { GestureTab(kind: gesture.kind) },
            set: { tab in
                switch tab {
                case .all:
                    kindBinding.wrappedValue = .radialMenu
                case .swipe:
                    if !gesture.kind.isDirectionalPan {
                        kindBinding.wrappedValue = .panRight
                    }
                case .zoom:
                    kindBinding.wrappedValue = .pinch
                }
            }
        )
    }

    private var swipeDirectionBinding: Binding<SwipeDirection> {
        Binding(
            get: { SwipeDirection(kind: gesture.kind) ?? .right },
            set: { kindBinding.wrappedValue = $0.kind }
        )
    }

    private var zoomGestureBinding: Binding<ZoomGesture> {
        Binding(
            get: { ZoomGesture(kind: gesture.kind) ?? .pinch },
            set: { kindBinding.wrappedValue = $0.kind }
        )
    }

    private var fingerCountBinding: Binding<Int> {
        Binding(
            get: { gesture.fingerCount },
            set: { count in
                gesture.fingerCount = count

                if isActivationZoneDisabled {
                    gesture.activationZone = .titlebar
                }
            }
        )
    }

    private var isActivationZoneDisabled: Bool {
        gesture.fingerCount <= 2
    }

    var body: some View {
        LuminareForm {
            LuminareSection(outerPadding: 0) {
                LuminareTextField(
                    gesture.defaultName,
                    text: Binding(
                        get: { gesture.name ?? "" },
                        set: { gesture.name = $0 }
                    )
                )
                .luminareFilledStates(.none)
                .luminareBorderedStates(.none)
            }

            LuminareSection {
                LuminarePicker(
                    compactElements: GestureTab.allCases,
                    selection: tabBinding
                ) { tab in
                    HStack(spacing: 6) {
                        tab.image
                            .frame(width: 12)

                        Text(tab.displayName)
                    }
                    .fixedSize()
                }
                .luminareContentSize(hasFixedHeight: true)
                .luminareRoundingBehavior(top: true, bottom: gesture.kind == .radialMenu)

                if GestureTab(kind: gesture.kind) == .swipe {
                    LuminarePickerMenu(
                        "Direction",
                        selection: swipeDirectionBinding,
                        items: SwipeDirection.allCases
                    ) { direction in
                        Text("\(direction.image) \(direction.displayName)")
                    }
                }

                if GestureTab(kind: gesture.kind) == .zoom {
                    LuminarePickerMenu(
                        "Gesture",
                        selection: zoomGestureBinding,
                        items: ZoomGesture.allCases
                    ) { gesture in
                        Text("\(gesture.image) \(gesture.displayName)")
                    }
                }
            }
            .luminareCornerRadius(16)

            LuminareSection {
                LuminareSliderPicker(
                    "Fingers",
                    Array(2...5),
                    selection: fingerCountBinding
                ) { count in
                    Text("\(count)")
                        .monospaced()
                }
                .luminareSliderPickerLayout(.compact(textBoxWidth: 24))

                LuminarePicker(
                    compactElements: GestureBinding.ActivationZone.allCases,
                    selection: $gesture.activationZone
                ) { option in
                    HStack(spacing: 6) {
                        Image(systemName: option.systemImage)

                        Text(option.displayName)
                    }
                    .fixedSize()
                }
                .luminareContentSize(hasFixedHeight: true)
                .luminareRoundingBehavior(bottom: true)
                .opacity(isActivationZoneDisabled ? 0.5 : 1)
                .disabled(isActivationZoneDisabled)
            }
            .luminareCornerRadius(16)

            Button {
                isPresented = false
            } label: {
                Text("Close", comment: "Label for a button that closes a modal window")
            }
            .buttonStyle(.luminare(overrideUseMainStyle: true))
            .luminareCornerRadius(8)
        }
        .animation(luminareAnimation, value: gesture.kind)
        .onChange(of: gesture) { externalGesture = $0 }
    }
}

private enum GestureTab: CaseIterable, Equatable {
    case all
    case swipe
    case zoom

    init(kind: GestureBinding.Kind) {
        switch kind {
        case .radialMenu:
            self = .all
        case .panUp, .panDown, .panLeft, .panRight:
            self = .swipe
        case .pinch, .spread:
            self = .zoom
        }
    }

    var displayName: String {
        switch self {
        case .all:
            String(localized: "Both", comment: "Gesture tab label: swipe and zoom gestures")
        case .swipe:
            String(localized: "Swipe", comment: "Gesture tab label: swipe")
        case .zoom:
            String(localized: "Zoom", comment: "Gesture tab label: zoom")
        }
    }

    var image: Image {
        switch self {
        case .all:
            Image(.loop)
        case .swipe:
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
        case .zoom:
            Image(systemName: "arrow.down.left.and.arrow.up.right")
        }
    }
}

private enum SwipeDirection: CaseIterable {
    case up
    case down
    case left
    case right

    init?(kind: GestureBinding.Kind) {
        switch kind {
        case .panUp:
            self = .up
        case .panDown:
            self = .down
        case .panLeft:
            self = .left
        case .panRight:
            self = .right
        case .radialMenu, .pinch, .spread:
            return nil
        }
    }

    var kind: GestureBinding.Kind {
        switch self {
        case .up:
            .panUp
        case .down:
            .panDown
        case .left:
            .panLeft
        case .right:
            .panRight
        }
    }

    var displayName: String {
        switch self {
        case .up:
            String(localized: "Up", comment: "Swipe direction picker option: up")
        case .down:
            String(localized: "Down", comment: "Swipe direction picker option: down")
        case .left:
            String(localized: "Left", comment: "Swipe direction picker option: left")
        case .right:
            String(localized: "Right", comment: "Swipe direction picker option: right")
        }
    }

    var image: Image {
        kind.image
    }
}

private enum ZoomGesture: CaseIterable {
    case pinch
    case spread

    init?(kind: GestureBinding.Kind) {
        switch kind {
        case .pinch:
            self = .pinch
        case .spread:
            self = .spread
        case .radialMenu, .panUp, .panDown, .panLeft, .panRight:
            return nil
        }
    }

    var kind: GestureBinding.Kind {
        switch self {
        case .pinch:
            .pinch
        case .spread:
            .spread
        }
    }

    var displayName: String {
        switch self {
        case .pinch:
            String(localized: "Pinch", comment: "Zoom gesture picker option: pinch")
        case .spread:
            String(localized: "Spread", comment: "Zoom gesture picker option: spread")
        }
    }

    var image: Image {
        kind.image
    }
}
