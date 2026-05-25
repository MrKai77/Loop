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
    @Published var selectedGestures = Set<Gesture>()
}

struct GesturesConfigurationView: View {
    @Environment(\.luminareAnimation) private var luminareAnimation
    @StateObject private var model = GesturesConfigurationModel()

    @Default(.enableGestures) private var enableGestures
    @Default(.disableConflictingSystemGestures) private var disableConflictingSystemGestures
    @Default(.gestures) private var gestures
    @Default(.gestureTitlebarHeight) private var gestureTitlebarHeight

    var body: some View {
        LuminareForm {
            settingsSection

            if enableGestures {
                gesturesSection
            }
        }
        .animation(luminareAnimation, value: enableGestures)
        .onChange(of: gestures) { newValue in
            let gesturesByID = Dictionary(uniqueKeysWithValues: newValue.map { ($0.id, $0) })
            let selectedIDs = model.selectedGestures.map(\.id)
            model.selectedGestures = Set(selectedIDs.compactMap { gesturesByID[$0] })
        }
    }

    private var settingsSection: some View {
        LuminareSection {
            LuminareToggle("Enable gestures", isOn: $enableGestures)

            if enableGestures {
                LuminareToggle("Disable conflicting system gestures", isOn: $disableConflictingSystemGestures)
            }
        }
    }

    private var gesturesSection: some View {
        LuminareSection(String(localized: "Gestures", comment: "Section header shown in gestures settings")) {
            LuminareButtonRow {
                Button("Add") {
                    gestures.insert(
                        Gesture(),
                        at: 0
                    )
                }

                Button("Remove", role: .destructive) {
                    let selectedIDs = Set(model.selectedGestures.map(\.id))
                    gestures.removeAll { selectedIDs.contains($0.id) }
                }
                .disabled(model.selectedGestures.isEmpty)
                .keyboardShortcut(.delete)
            }
            .luminareRoundingBehavior(top: true)

            LuminareList(
                items: $gestures,
                selection: $model.selectedGestures,
                id: \.id
            ) { gesture in
                GestureItemView(gesture)
            } emptyView: {
                HStack {
                    Spacer()
                    VStack {
                        Text("No gestures")
                            .font(.title3)
                        Text("Press \"Add\" to add a gesture")
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
