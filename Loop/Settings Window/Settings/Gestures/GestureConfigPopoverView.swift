//
//  GestureConfigPopoverView.swift
//  Loop
//
//  Created by Kai Azim on 2026-04-16.
//

import Luminare
import SwiftUI

struct GestureConfigPopoverView: View {
    @State private var gesture: Gesture
    @Binding private var externalGesture: Gesture

    init(gesture: Binding<Gesture>) {
        self.gesture = gesture.wrappedValue
        self._externalGesture = gesture
    }

    private var kindBinding: Binding<Gesture.Kind> {
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

    var body: some View {
        LuminareSection {
            LuminareCompose(String(localized: "Gesture Type", comment: "Label in the gesture configuration popover")) {
                Picker("", selection: kindBinding) {
                    ForEach(Array(Gesture.Kind.allCases.enumerated()), id: \.element) { _, kind in
                        HStack {
                            kind.image
                                .frame(width: 12)

                            Text(kind.displayName)
                        }
                        .tag(kind)
                    }
                }
                .labelsHidden()
            }

            LuminareCompose(String(localized: "Fingers", comment: "Label for the finger-count stepper in the gesture configuration popover")) {
                HStack {
                    Text("\(gesture.fingerCount)")

                    Stepper("", value: $gesture.fingerCount, in: 2...5)
                        .labelsHidden()
                        .onChange(of: gesture.fingerCount) { count in
                            if count <= 2 { gesture.activationZone = .titlebar }
                        }
                }
            }

            LuminareCompose(String(localized: "Activation Zone", comment: "Label for the activation zone picker in the gesture configuration popover")) {
                Picker("", selection: $gesture.activationZone) {
                    ForEach(Gesture.ActivationZone.allCases, id: \.self) { zone in
                        Label(zone.displayName, systemImage: zone.systemImage)
                            .tag(zone)
                    }
                }
                .labelsHidden()
                .disabled(gesture.fingerCount <= 2)
            }
            .help(gesture.fingerCount <= 2 ? String(localized: "2-finger gestures are restricted to the titlebar to avoid conflicting with system gestures.", comment: "Help text shown when the activation zone picker is disabled for 2-finger gestures") : "")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: gesture) { externalGesture = $0 }
        .luminareFilledStates(.none)
        .luminareBorderedStates(.none)
        .padding(8)
    }
}
