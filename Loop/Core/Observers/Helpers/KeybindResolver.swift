//
//  KeybindResolver.swift
//  Loop
//
//  Created by Kai Azim on 2026-08-28.
//

import CoreGraphics

/// Matches keyboard events without mutating `KeybindTrigger` state
enum KeybindResolver {
    enum EventType {
        case keyDown
        case keyUp
        case flagsChanged
    }

    struct TriggerConfiguration {
        let keys: Set<CGKeyCode>
        let isSideDependent: Bool

        var normalizedKeys: Set<CGKeyCode> {
            isSideDependent ? keys : keys.baseModifiers
        }
    }

    struct Input {
        let eventType: EventType
        let isRepeat: Bool
        let pressedKeys: Set<CGKeyCode>
        let modifierKeys: Set<CGKeyCode>
        let trigger: TriggerConfiguration
        let isLoopOpen: Bool
        let actionsByKeybind: [Set<CGKeyCode>: WindowAction]
        let bypassedActionsByKeybind: [Set<CGKeyCode>: WindowAction]
    }

    enum ActionSource: Equatable {
        case trigger
        case bypassTrigger
    }

    enum ActionCategory: Equatable {
        case cycle
        case repeatableNonCycle
        case nonRepeatable

        init(action: WindowAction) {
            if action.direction == .cycle {
                self = .cycle
            } else if action.canRepeat {
                self = .repeatableNonCycle
            } else {
                self = .nonRepeatable
            }
        }

        fileprivate var canActivateOnRepeat: Bool {
            self == .repeatableNonCycle
        }
    }

    enum Activation: Equatable {
        case activate
        case suppressAutorepeat
    }

    enum Match: Equatable {
        case none
        case escape
        case triggerReleasedWhileOpen
        case triggerOnly
        case action(
            WindowAction,
            source: ActionSource,
            category: ActionCategory,
            activation: Activation
        )
    }

    enum Effect: Equatable {
        case none
        case open(
            action: WindowAction,
            overrideExistingTriggerDelayAction: Bool
        )
        case close(
            force: Bool,
            notifyDoubleClickKeyUp: Bool
        )
    }

    enum HandlingIntent: Equatable {
        case forward
        case consume
        case opening

        case consumeIfLoopOpenOtherwiseOpening

        func resolve(isLoopOpenAfterEffect: Bool) -> ResolvedHandling {
            switch self {
            case .forward:
                .forward
            case .consume:
                .consume
            case .opening:
                .opening
            case .consumeIfLoopOpenOtherwiseOpening:
                isLoopOpenAfterEffect ? .consume : .opening
            }
        }
    }

    enum ResolvedHandling: Equatable {
        case forward
        case consume
        case opening
    }

    struct Decision {
        let match: Match
        let effect: Effect
        let handling: HandlingIntent
    }

    /// Resolves an event using eager, exact key matching.
    ///
    /// Key-up events never match actions, so releasing a chord cannot trigger its subset.
    static func resolve(_ input: Input) -> Decision {
        let modifierKeys = input.trigger.isSideDependent
            ? input.modifierKeys
            : input.modifierKeys.baseModifiers
        let allPressedKeys = input.pressedKeys.union(modifierKeys)
        let triggerKeys = input.trigger.normalizedKeys
        let containsTrigger = allPressedKeys.isSuperset(of: triggerKeys)
        let actionKeys = allPressedKeys.subtracting(triggerKeys).baseModifiers
        let allPressedKeysBaseModifiers = allPressedKeys.baseModifiers

        if input.isLoopOpen {
            if input.pressedKeys.contains(.kVK_Escape) {
                return .init(
                    match: .escape,
                    effect: .close(force: true, notifyDoubleClickKeyUp: false),
                    handling: .consume
                )
            }

            if input.eventType == .keyUp {
                return .init(match: .none, effect: .none, handling: .forward)
            }

            if input.eventType != .keyDown, !containsTrigger {
                return .init(
                    match: .triggerReleasedWhileOpen,
                    effect: .close(force: false, notifyDoubleClickKeyUp: false),
                    handling: .forward
                )
            }
        }

        guard input.eventType != .keyUp else {
            return .init(match: .none, effect: .none, handling: .forward)
        }

        if containsTrigger {
            if let action = input.actionsByKeybind[actionKeys] {
                return actionDecision(
                    action,
                    source: .trigger,
                    isRepeat: input.isRepeat
                )
            }

            if allPressedKeys == triggerKeys {
                return .init(
                    match: .triggerOnly,
                    effect: .open(
                        action: .init(.noSelection),
                        overrideExistingTriggerDelayAction: !input.isRepeat
                    ),
                    handling: .opening
                )
            }
        } else if let action = input.bypassedActionsByKeybind[allPressedKeysBaseModifiers] {
            return actionDecision(
                action,
                source: .bypassTrigger,
                isRepeat: input.isRepeat
            )
        } else {
            return .init(
                match: .none,
                effect: .close(
                    force: false,
                    notifyDoubleClickKeyUp: allPressedKeys.isEmpty
                ),
                handling: .forward
            )
        }

        return .init(match: .none, effect: .none, handling: .forward)
    }

    private static func actionDecision(
        _ action: WindowAction,
        source: ActionSource,
        isRepeat: Bool
    ) -> Decision {
        let category = ActionCategory(action: action)
        let activation: Activation = !isRepeat || category.canActivateOnRepeat
            ? .activate
            : .suppressAutorepeat
        let effect: Effect = switch activation {
        case .activate:
            .open(action: action, overrideExistingTriggerDelayAction: true)
        case .suppressAutorepeat:
            .none
        }

        return .init(
            match: .action(
                action,
                source: source,
                category: category,
                activation: activation
            ),
            effect: effect,
            handling: .consumeIfLoopOpenOtherwiseOpening
        )
    }
}
