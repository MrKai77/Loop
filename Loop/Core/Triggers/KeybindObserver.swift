//
//  KeybindObserver.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-18.
//

import Cocoa
import Defaults

/// Monitors `keyDown`, `keyUp`, and `flagsChanged` events using an ActiveEventMonitor, invoking Loop’s open and close callbacks as needed.
/// Additionally, this class manages keybind action retrieval and updates Loop based on those actions.
final class KeybindObserver {
    // Callbacks
    private let openCallback: (WindowAction?) -> ()
    private let closeCallback: (Bool) -> ()
    private let checkIfLoopOpen: () -> Bool

    // State-tracking
    private var pressedKeys: Set<CGKeyCode> = []
    private var previousEventFlags: CGEventFlags = []
    private var lastKeyReleaseTime: Date = .now
    private var eventMonitor: ActiveEventMonitor?

    // Special events only contain the globe key, as it can also be used as an emoji key.
    private let specialEvents: [CGKeyCode] = [.kVK_Globe_Emoji]
    var canPassthroughSpecialEvents = true // If mouse has been moved

    private let actionsByKeybindCache = WindowActionCache()

    private var useTriggerDelay: Bool { Defaults[.triggerDelay] > 0.1 }
    private var doubleClickToTrigger: Bool { Defaults[.doubleClickToTrigger] }
    private var sideDependentTriggerKey: Bool { Defaults[.sideDependentTriggerKey] }
    private var triggerKey: Set<CGKeyCode> {
        sideDependentTriggerKey ? Defaults[.triggerKey] : Defaults[.triggerKey].baseModifiers
    }

    private lazy var triggerDelayTimer = TriggerDelayTimer(openCallback: openCallback)
    private lazy var doubleClickTimer = DoubleClickTimer { [weak self] action in
        guard let self else { return }

        if useTriggerDelay {
            startTriggerDelayTimer(
                startingAction: action,
                overrideExistingTriggerDelayTimerAction: true
            )
        } else {
            openCallback(action)
        }
    }

    /// Initializes a ``KeybindObserver``.
    /// - Parameters:
    ///   - openCallback: what to do when the trigger key is pressed, and Loop should be activated.
    ///   - closeCallback: what to do when the trigger key is released, and Loop should be closed.
    init(
        openCallback: @escaping (WindowAction?) -> (),
        closeCallback: @escaping (Bool) -> (),
        checkIfLoopOpen: @escaping () -> Bool
    ) {
        self.openCallback = openCallback
        self.closeCallback = closeCallback
        self.checkIfLoopOpen = checkIfLoopOpen
    }

    @MainActor
    func start() {
        guard AccessibilityManager.shared.isGranted else {
            return
        }

        eventMonitor?.stop()

        let eventMonitor = ActiveEventMonitor(events: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event -> ActiveEventMonitor.EventHandling in
            guard let self else { return .forward }

            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                .baseKey(flags: .init(rawValue: UInt(event.flags.rawValue)))

            LoopManager.shared.isShiftKeyPressed = event.flags.contains(.maskShift)

            var filteredFlags = event.flags

            if keyCode.isFnSpecialKey, !previousEventFlags.contains(.maskSecondaryFn) {
                filteredFlags.remove(.maskSecondaryFn)
            }

            previousEventFlags = filteredFlags

            if event.type == .keyUp {
                pressedKeys.remove(keyCode)
            } else if event.type == .keyDown {
                pressedKeys.insert(keyCode)
            }

            // Special events such as the emoji key
            if specialEvents.contains(keyCode) {
                return canPassthroughSpecialEvents ? .forward : .ignore
            }

            // If this is a valid event, don't passthrough
            if performKeybind(
                type: event.type,
                isARepeat: event.getIntegerValueField(.keyboardEventAutorepeat) == 1,
                flags: filteredFlags
            ) {
                return .ignore
            }

            // If this wasn't, check if it was a system keybind (ex. screenshot), and
            // in that case, passthrough and force-close Loop
            if CGKeyCode.systemKeybinds.contains(pressedKeys) {
                closeCallback(true)
            }

            return .forward
        }

        eventMonitor.start()
        self.eventMonitor = eventMonitor
    }

    @MainActor
    func stop() {
        pressedKeys = []
        canPassthroughSpecialEvents = true

        eventMonitor?.stop()
        eventMonitor = nil
    }

    /// Determines if an event corresponds to a valid Loop action.
    /// - Parameters:
    ///   - type: the type of this event.
    ///   - isARepeat: whether this event is a repeat event.
    ///   - flags: modifier flags associated with this event.
    /// - Returns: whether this event was processed by Loop.
    private func performKeybind(type: CGEventType, isARepeat: Bool, flags: CGEventFlags) -> Bool {
        let flagKeys = sideDependentTriggerKey ? flags.keyCodes : flags.keyCodes.baseModifiers
        let allPressedKeys: Set<CGKeyCode> = pressedKeys.union(flagKeys)
        let actionKeys: Set<CGKeyCode> = allPressedKeys.subtracting(triggerKey)
        let containsTrigger = allPressedKeys.isSuperset(of: triggerKey)

        if checkIfLoopOpen() {
            if pressedKeys.contains(.kVK_Escape) {
                closeLoop(forceClose: true)
                return true
            }

            if type == .keyUp {
                // Ignore key-up events occurring within 100ms of each other.
                // Prevents direction changes when rapidly (normally) releasing multiple pressed keys.
                if abs(lastKeyReleaseTime.timeIntervalSinceNow) > 0.1 {
                    lastKeyReleaseTime = Date.now
                }

                return false
            }

            if type != .keyDown, !containsTrigger {
                closeLoop(forceClose: false)
                return true
            }
        }

        if type != .keyUp {
            if containsTrigger {
                if let action = actionsByKeybindCache[actionKeys] {
                    if !isARepeat || action.willManipulateExistingWindowFrame {
                        openLoop(startingAction: action, overrideExistingTriggerDelayTimerAction: true)
                    }
                    return true
                }

                // Only trigger Loop without an action if the only pressed keys perfectly matches the trigger key.
                if allPressedKeys == triggerKey {
                    openLoop(startingAction: nil, overrideExistingTriggerDelayTimerAction: !isARepeat)
                    return false
                }
            } else {
                closeLoop(forceClose: false)
            }
        }

        // If this wasn't a valid keybind, return false, which will then forward the key event to the frontmost app
        return false
    }

    private func openLoop(startingAction: WindowAction?, overrideExistingTriggerDelayTimerAction: Bool) {
        if checkIfLoopOpen() {
            openCallback(startingAction) // Only update Loop to the latest WindowAction
        } else {
            if doubleClickToTrigger {
                doubleClickTimer.handleTrigger(startingAction: startingAction)
            } else if useTriggerDelay {
                startTriggerDelayTimer(
                    startingAction: startingAction,
                    overrideExistingTriggerDelayTimerAction: overrideExistingTriggerDelayTimerAction
                )
            } else {
                openCallback(startingAction)
            }
        }
    }

    private func closeLoop(forceClose: Bool) {
        pressedKeys = []
        canPassthroughSpecialEvents = true
        triggerDelayTimer.cancel()
        closeCallback(forceClose)
    }

    private func startTriggerDelayTimer(
        startingAction: WindowAction?,
        overrideExistingTriggerDelayTimerAction: Bool
    ) {
        // If a trigger delay timer is already active, only update its startingAction when
        // overrideExistingTriggerDelayTimerAction is true. If it's false, keep the existing
        // timer and its startingAction (do not create a new timer with nil).
        if triggerDelayTimer.isActive {
            if overrideExistingTriggerDelayTimerAction {
                triggerDelayTimer.updateStartingAction(with: startingAction)
            }
        } else {
            // No active timer, create one with the provided startingAction.
            triggerDelayTimer.handleTrigger(startingAction: startingAction)
        }
    }
}
