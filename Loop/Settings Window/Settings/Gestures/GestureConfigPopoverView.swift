//
//  GestureConfigPopoverView.swift
//  Loop
//
//  Created by Kai Azim on 2026-04-16.
//

import Luminare
import SwiftUI

struct GestureConfigPopoverView: View {
    @State private var binding: GestureBinding
    @Binding private var externalBinding: GestureBinding

    init(binding: Binding<GestureBinding>) {
        self.binding = binding.wrappedValue
        self._externalBinding = binding
    }

    private var gestureTypeBinding: Binding<GestureBinding.GestureType> {
        Binding(
            get: { binding.gestureType },
            set: { newType in
                let oldType = binding.gestureType
                binding.gestureType = newType

                if newType == .radialMenu {
                    binding.action = .radialMenuActions
                } else if oldType == .radialMenu {
                    binding.action = .singleAction(.custom(.init(.noAction)))
                }
            }
        )
    }

    var body: some View {
        LuminareSection {
            LuminareCompose("Gesture Type") {
                Picker("", selection: gestureTypeBinding) {
                    ForEach(Array(GestureBinding.GestureType.allCases.enumerated()), id: \.element) { _, type in
                        HStack {
                            type.image
                                .frame(width: 12)

                            Text(type.displayName)
                        }
                        .tag(type)
                    }
                }
                .labelsHidden()
            }

            LuminareCompose("Fingers") {
                HStack {
                    Text("\(binding.fingerCount)")

                    Stepper("", value: $binding.fingerCount, in: 2...5)
                        .labelsHidden()
                        .onChange(of: binding.fingerCount) { count in
                            if count <= 2 { binding.activationZone = .titlebar }
                        }
                }
            }

            LuminareCompose("Activation Zone") {
                Picker("", selection: $binding.activationZone) {
                    ForEach(GestureBinding.ActivationZone.allCases, id: \.self) { zone in
                        Label(zone.displayName, systemImage: zone.systemImage)
                            .tag(zone)
                    }
                }
                .labelsHidden()
                .disabled(binding.fingerCount <= 2)
            }
            .help(binding.fingerCount <= 2 ? "2-finger gestures are restricted to the titlebar to avoid conflicting with system gestures." : "")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: binding) { externalBinding = $0 }
        .luminareFilledStates(.none)
        .luminareBorderedStates(.none)
        .padding(8)
    }
}
