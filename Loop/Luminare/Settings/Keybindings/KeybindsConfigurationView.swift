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
    @Environment(\.luminareAnimation) private var luminareAnimation

    @StateObject private var model = KeybindsConfigurationModel()

    @Default(.triggerKey) var triggerKey
    @Default(.triggerDelay) var triggerDelay
    @Default(.cycleModeRestartEnabled) var cycleModeRestartEnabled
    @Default(.cycleBackwardsOnShiftPressed) var cycleBackwardsOnShiftPressed
    @Default(.doubleClickToTrigger) var doubleClickToTrigger
    @Default(.middleClickTriggersLoop) var middleClickTriggersLoop
    @Default(.enableTriggerDelayOnMiddleClick) var enableTriggerDelayOnMiddleClick
    @Default(.keybinds) var keybinds

    /// If the user has "enabled" the trigger delay.
    private var useTriggerDelay: Bool {
        Defaults[.triggerDelay] != 0
    }

    /// Is there at least one keybind action that is a cycle?
    private var isCycleActionPresentInKeybinds: Bool {
        keybinds.contains(where: { $0.cycle != nil })
    }

    /// Is Shift used in the trigger key?
    private var isShiftUsedByTriggerKey: Bool {
        triggerKey.map(\.baseKey).contains(.kVK_Shift)
    }

    private var showMiddleClickTriggerDelayOption: Bool {
        middleClickTriggersLoop && useTriggerDelay
    }

    private var showCycleRestartOption: Bool {
        isCycleActionPresentInKeybinds
    }

    private var showCycleBackwardsOption: Bool {
        isCycleActionPresentInKeybinds && !isShiftUsedByTriggerKey
    }

    var body: some View {
        Group {
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
                    clampsUpper: false,
                    suffix: .init(.init(localized: "Measurement unit: seconds", defaultValue: "s"))
                )

                LuminareToggle("Double-click to trigger", isOn: $doubleClickToTrigger)
                LuminareToggle("Middle-click to trigger", isOn: $middleClickTriggersLoop)

                if showMiddleClickTriggerDelayOption {
                    LuminareToggle("Apply trigger delay on middle-click", isOn: $enableTriggerDelayOnMiddleClick)
                }

                if showCycleRestartOption {
                    LuminareToggle(isOn: $cycleModeRestartEnabled) {
                        Text("Always start cycles from first item")
                            .padding(.trailing, 4)
                            .luminarePopover(attachedTo: .topTrailing) {
                                Text("By default, Loop resumes cycles from where you last left off in each window.")
                                    .padding(6)
                            }
                    }
                }

                if showCycleBackwardsOption {
                    LuminareToggle("Cycle backward with Shift", isOn: $cycleBackwardsOnShiftPressed)
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
        .animation(
            luminareAnimation,
            value: [
                showMiddleClickTriggerDelayOption,
                cycleModeRestartEnabled,
                showCycleBackwardsOption
            ]
        )
    }
}

#Preview {
    KeybindsConfigurationView()
        .frame(width: 300)
}
