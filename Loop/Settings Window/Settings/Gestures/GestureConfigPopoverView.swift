//
//  GestureConfigPopoverView.swift
//  Loop
//
//  Created by Kai Azim on 2026-04-16.
//

import SwiftUI
import Luminare

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
                    TextField("", value: $binding.fingerCount, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 40)
                    
                    Stepper("", value: $binding.fingerCount, in: 2...5)
                        .labelsHidden()
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: binding) { externalBinding = $0 }
        .luminareFilledStates(.none)
        .luminareBorderedStates(.none)
    }
}
