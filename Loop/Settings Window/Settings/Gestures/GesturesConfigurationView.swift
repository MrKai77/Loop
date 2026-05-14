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

    var body: some View {
        LuminareForm {
            settingsSection
            bindingsSection
                .disabled(!enableGestures)
        }
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
            LuminareButtonRow {
                Button("Add") {
                    gestureBindings.insert(
                        GestureBinding(),
                        at: 0
                    )
                }

                Button("Remove", role: .destructive) {
                    let selectedIDs = Set(model.selectedBindings.map(\.id))
                    gestureBindings.removeAll { selectedIDs.contains($0.id) }
                }
                .disabled(model.selectedBindings.isEmpty)
                .keyboardShortcut(.delete)
            }
            .luminareRoundingBehavior(top: true)

            LuminareList(
                items: $gestureBindings,
                selection: $model.selectedBindings,
                id: \.id
            ) { binding in
                GestureBindingItemView(binding)
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
