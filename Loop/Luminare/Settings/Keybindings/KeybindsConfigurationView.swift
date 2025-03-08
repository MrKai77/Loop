//
//  KeybindsConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-20.
//

import Defaults
import Luminare
import SwiftUI

class KeybindsConfigurationModel: ObservableObject {
    @Published var currentEventMonitor: NSEventMonitor?
    @Published var selectedKeybinds = Set<WindowAction>()
}

struct KeybindsConfigurationView: View {
    @StateObject private var model = KeybindsConfigurationModel()

    @Default(.triggerKey) var triggerKey
    @Default(.triggerDelay) var triggerDelay
    @Default(.doubleClickToTrigger) var doubleClickToTrigger
    @Default(.middleClickTriggersLoop) var middleClickTriggersLoop
    @Default(.keybinds) var keybinds

    var body: some View {
        LuminareSection("Trigger Key") {
            TriggerKeycorder($triggerKey)
                .environmentObject(model)
                .luminareBordered(true)
        }
        .luminareBordered(false)

        LuminareSection("Settings") {
//            LuminareValueAdjuster(
//                "Trigger delay",
//                value: $model.triggerDelay,
//                sliderRange: 0...1,
//                suffix: .init(.init(localized: "Measurement unit: seconds", defaultValue: "s")),
//                step: 0.1,
//                lowerClamp: true,
//                decimalPlaces: 1
//            )
            LuminareSlider(
                "Trigger delay",
                value: $triggerDelay,
                in: 0...1,
                clampsLower: true,
                suffix: .init(.init(localized: "Measurement unit: seconds", defaultValue: "s")),
                maxDecimalPlaces: 1
            )

            LuminareToggle("Double-click to trigger", isOn: $doubleClickToTrigger)
            LuminareToggle("Middle-click to trigger", isOn: $middleClickTriggersLoop)
        }

        LuminareSection("Keybinds") {
            HStack(spacing: 2) {
                Button("Add") {
                    keybinds.insert(.init(.noAction), at: 0)
                }

                Button("Remove", role: .destructive) {
                    keybinds.removeAll(where: model.selectedKeybinds.contains)
                }
                .disabled(model.selectedKeybinds.isEmpty)
                .buttonStyle(.luminareProminent)
            }

            LuminareList(
                items: $keybinds,
                selection: $model.selectedKeybinds,
                id: \.id
            ) { keybind in
                KeybindItemView(keybind)
                    .environmentObject(model)
            } emptyView: {
                HStack {
                    Spacer()
                    VStack {
                        Text("No keybinds")
                            .font(.title3)
                        Text("Press \"Add\" to add a keybind")
                            .font(.caption)
                    }
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding()
            }
            .luminareListRoundedCorner(bottom: .always)
        }
    }
}

#Preview {
    KeybindsConfigurationView()
        .frame(width: 300)
}
