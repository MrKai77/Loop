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
    @Default(.cycleBackwardsOnShiftPressed) var cycleBackwardsOnShiftPressed
    @Default(.doubleClickToTrigger) var doubleClickToTrigger
    @Default(.middleClickTriggersLoop) var middleClickTriggersLoop
    @Default(.keybinds) var keybinds

    /// Is there at least one keybind action that is a cycle?
    private var isCycleActionPresentInKeybinds: Bool {
        keybinds.contains(where: { $0.cycle != nil })
    }

    /// Is Shift used in the trigger key?
    var isShiftUsedByTriggerKey: Bool {
        triggerKey.contains(.kVK_Shift)
    }

    var body: some View {
        LuminareSection("Trigger Key") {
            TriggerKeycorder($triggerKey)
                .environmentObject(model)
                .luminareBordered(true)
        }
        .luminareBordered(false)

        LuminareSection("Settings") {
            LuminareSlider(
                "Trigger delay",
                value: $triggerDelay,
                in: 0...1,
                step: 0.1,
                format: .number.precision(.fractionLength(1...1)),
                clampsLower: true,
                suffix: .init(.init(localized: "Measurement unit: seconds", defaultValue: "s"))
            )

            LuminareToggle("Double-click to trigger", isOn: $doubleClickToTrigger)
            LuminareToggle("Middle-click to trigger", isOn: $middleClickTriggersLoop)

            if isCycleActionPresentInKeybinds {
                LuminareToggle(isOn: $cycleBackwardsOnShiftPressed) {
                    Text("Cycle backward with Shift")
                        .padding(.trailing, 4)
                        .luminarePopover(attachedTo: .topTrailing) {
                            Text("Cycling actions backward will only work\nif Shift isn't in your trigger key")
                                .padding(6)
                        }
                        .luminareTint(overridingWith: .blue)
                }
            }
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
                .keyboardShortcut(.delete)
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
