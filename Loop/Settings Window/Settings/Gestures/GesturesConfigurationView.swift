//
//  GesturesConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2026-04-16.
//

import Defaults
import Luminare
import SwiftUI

final class GesturesConfigurationModel: ObservableObject {
    @Published var selectedBindings = Set<GestureBinding>()
}

struct GesturesConfigurationView: View {
    @Environment(\.luminareAnimation) private var luminareAnimation
    @StateObject private var model = GesturesConfigurationModel()

    @Default(.enableGestures) private var enableGestures
    @Default(.gestureBindings) private var gestureBindings
    @Default(.gestureTitlebarHeight) private var gestureTitlebarHeight

    private var conflictingIDs: Set<UUID> {
        GestureBinding.conflictingIDs(in: gestureBindings)
    }

    var body: some View {
        Group {
            settingsSection
            bindingsSection
                .disabled(!enableGestures)
        }
        // GestureBinding's synthesized Hashable covers its mutable fields,
        // so editing a selected binding rehashes the stored struct and the
        // Set goes stale. Reconcile by id after every change.
        .onChange(of: gestureBindings) { newValue in
            let bindingsByID = Dictionary(uniqueKeysWithValues: newValue.map { ($0.id, $0) })
            let selectedIDs = model.selectedBindings.map(\.id)
            model.selectedBindings = Set(selectedIDs.compactMap { bindingsByID[$0] })
        }
    }

    private var settingsSection: some View {
        LuminareSection {
            LuminareToggle("Enable gestures", isOn: $enableGestures)
        }
    }

    private var bindingsSection: some View {
        LuminareSection(String(localized: "Gesture Bindings", comment: "Section header shown in gestures settings")) {
            HStack(spacing: 4) {
                Button("Add") {
                    gestureBindings.insert(
                        GestureBinding(),
                        at: 0
                    )
                }
                .luminareRoundingBehavior(topLeading: true)

                Button("Remove", role: .destructive) {
                    let selectedIDs = Set(model.selectedBindings.map(\.id))
                    gestureBindings.removeAll { selectedIDs.contains($0.id) }
                }
                .luminareRoundingBehavior(topTrailing: true)
                .disabled(model.selectedBindings.isEmpty)
                .keyboardShortcut(.delete)
            }

            LuminareList(
                items: $gestureBindings,
                selection: $model.selectedBindings,
                id: \.id
            ) { binding in
                GestureBindingItemView(
                    binding,
                    hasConflict: conflictingIDs.contains(binding.wrappedValue.id)
                )
            } emptyView: {
                HStack {
                    Spacer()
                    VStack {
                        Text("No gesture bindings")
                            .font(.title3)
                        Text("Press \"Add\" to add a gesture binding")
                            .font(.caption)
                    }
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding()
            }
            .luminareRoundingBehavior(bottom: true)
        }
    }
}
