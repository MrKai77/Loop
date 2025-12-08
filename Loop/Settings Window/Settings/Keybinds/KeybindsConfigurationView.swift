//
//  KeybindsConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-20.
//

import Defaults
import Luminare
import SwiftUI

final class KeybindsConfigurationModel: ObservableObject {
    @Published var currentEventMonitor: LocalEventMonitor?
    @Published var selectedKeybinds = Set<WindowAction>()
}

struct KeybindsConfigurationView: View {
    @Environment(\.luminareAnimation) private var luminareAnimation

    @StateObject private var model = KeybindsConfigurationModel()

    @Default(.triggerKey) private var triggerKey
    @Default(.sideDependentTriggerKey) private var sideDependentTriggerKey
    @Default(.triggerDelay) private var triggerDelay
    @Default(.cycleModeRestartEnabled) private var cycleModeRestartEnabled
    @Default(.cycleBackwardsOnShiftPressed) private var cycleBackwardsOnShiftPressed
    @Default(.doubleClickToTrigger) private var doubleClickToTrigger
    @Default(.middleClickTriggersLoop) private var middleClickTriggersLoop
    @Default(.enableTriggerDelayOnMiddleClick) private var enableTriggerDelayOnMiddleClick
    @Default(.keybinds) private var keybinds

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
        triggerKey.map(\.baseModifier).contains(.kVK_Shift)
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
            triggerKeySection
            settingsSection
            keybindsSection
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

    private var triggerKeySection: some View {
        LuminareSection(String(localized: "Trigger Key", comment: "Section header shown in settings")) {
            TriggerKeycorder($triggerKey)
                .environmentObject(model)
                .luminareBorderedStates(.normal)
        }
        .luminareBorderedStates(.none)
    }

    private var settingsSection: some View {
        Group {
            LuminareSection(String(localized: "Settings", comment: "Section header shown in settings")) {
                LuminareToggle("Treat left and right keys differently", isOn: $sideDependentTriggerKey)

                LuminareSlider(
                    "Trigger delay",
                    value: $triggerDelay,
                    in: 0...1,
                    step: 0.1,
                    format: .number.precision(.fractionLength(1...1)),
                    clampsUpper: false,
                    suffix: Text("s", comment: "Unit symbol: seconds")
                )

                LuminareToggle("Double-click to trigger", isOn: $doubleClickToTrigger)
                LuminareToggle("Middle-click to trigger", isOn: $middleClickTriggersLoop)

                if showMiddleClickTriggerDelayOption {
                    LuminareToggle("Apply trigger delay on middle-click", isOn: $enableTriggerDelayOnMiddleClick)
                }
            }

            if showCycleRestartOption || showCycleBackwardsOption {
                LuminareSection(String(localized: "Cycles", comment: "Section header shown in settings")) {
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
            }
        }
    }

    private var keybindsSection: some View {
        LuminareSection(String(localized: "Keybinds", comment: "Section header shown in settings")) {
            HStack(spacing: 4) {
                Button("Add") {
                    keybinds.insert(.init(.noAction), at: 0)
                }
                .luminareRoundingBehavior(topLeading: true)

                Button("Remove", role: .destructive) {
                    keybinds.removeAll(where: model.selectedKeybinds.contains)
                }
                .luminareRoundingBehavior(topTrailing: true)
                .disabled(model.selectedKeybinds.isEmpty)
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
            .luminareRoundingBehavior(bottom: true)
        }
    }
}

#Preview {
    KeybindsConfigurationView()
        .frame(width: 300)
}
