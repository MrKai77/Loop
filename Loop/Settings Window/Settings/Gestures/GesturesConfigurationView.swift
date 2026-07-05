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
    @Published var selectedGestures = Set<GestureBinding>()
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
            LuminareToggle(String(localized: "Enable trackpad gestures", comment: "Toggle in gestures settings"), isOn: $enableGestures)

            if enableGestures {
                LuminareToggle(String(localized: "Disable conflicting system gestures", comment: "Toggle in gestures settings"), isOn: $disableConflictingSystemGestures)
            }
        }
    }

    private var gesturesSection: some View {
        LuminareSection(String(localized: "Gestures", comment: "Section header shown in gestures settings")) {
            LuminareButtonRow {
                Button(String(localized: "Add", comment: "Button to add a new gesture")) {
                    gestures.insert(
                        GestureBinding(),
                        at: 0
                    )
                }

                Button(String(localized: "Remove", comment: "Button to remove selected gestures"), role: .destructive) {
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
                        Text(String(localized: "No gestures", comment: "Empty state title in gestures settings"))
                            .font(.title3)
                        Text(String(localized: "Press \"Add\" to add a gesture", comment: "Empty state subtitle in gestures settings"))
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
