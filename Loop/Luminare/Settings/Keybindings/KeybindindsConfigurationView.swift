//
//  KeybindingsConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-20.
//

import SwiftUI
import Luminare
import Defaults

struct KeybindingsConfigurationView: View {
    @Default(.triggerKey) var triggerKey
    @Default(.triggerDelay) var triggerDelay
    @Default(.doubleClickToTrigger) var doubleClickToTrigger
    @Default(.middleClickTriggersLoop) var middleClickTriggersLoop

    @StateObject private var keycorderModel = KeycorderModel()

    @State var keybinds = Defaults[.keybinds]
    @State private var selectedKeybinds = Set<WindowAction>()

    var body: some View {
        LuminareSection("Trigger Key", noBorder: true) {
            HStack {
                TriggerKeycorder($triggerKey)
                    .environmentObject(keycorderModel)

                Spacer()

                Button("Change") {
                    print("change trigger key")
                }
                .buttonStyle(LuminareCompactButtonStyle())
                .fixedSize()
            }
        }

        LuminareSection("Settings") {
            LuminareValueAdjuster(
                "Trigger delay",
                value: $triggerDelay,
                sliderRange: 0...1,
                suffix: "s",
                lowerClamp: true,
                decimalPlaces: 1
            )

            LuminareToggle("Double-click to trigger", isOn: $doubleClickToTrigger)
            LuminareToggle("Middle-click to trigger", isOn: $middleClickTriggersLoop)
        }

        LuminareList(
            "Keybinds",
            items: $keybinds,
            selection: $selectedKeybinds,
            addAction: { self.keybinds.insert(.init(.noAction), at: 0) },
            content: { keybind in
                KeybindingItemView(keybind)
                    .environmentObject(keycorderModel)
            }
        )
        .onChange(of: self.keybinds) { _ in
            Defaults[.keybinds] = keybinds
        }
        .onAppear {
            keybinds = Defaults[.keybinds]
        }
    }
}
