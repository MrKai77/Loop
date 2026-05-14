//
//  KeybindTrigger.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-18.
//

import Cocoa
import Defaults
import Scribe

/// Monitors `keyDown`, `keyUp`, and `flagsChanged` events using an ActiveEventMonitor, invoking Loop’s open and close callbacks as needed.
/// Additionally, this class manages keybind action retrieval and updates Loop based on those actions.
@Loggable
final class KeybindTrigger {
    // Parameters
    private let windowActionCache: WindowActionCache
    private let openCallback: (WindowAction) -> ()
    private let closeCallback: (Bool) -> ()
    private let checkIfLoopOpen: () -> Bool

    // State-tracking
    private var pressedKeys: Set<CGKeyCode> = []
    private(set) var effectiveEventFlags: CGEventFlags = []
    private var eventMonitor: ActiveEventMonitor?

    private var systemKeybindCache: Set<Set<CGKeyCode>> = []
    private var keybindCacheUpdatedAt: ContinuousClock.Instant?
    private let keybindCacheLifetime: ContinuousClock.Duration = .seconds(30)

    /// Special events only contain the globe key, as it can also be used as an emoji key.
    private let specialEventKeys: [CGKeyCode] = [.kVK_Globe_Emoji]

    /// Will be set to `false` if the mouse has been moved by LoopManager.
    var canPassthroughNextSpecialEvent = true

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
        windowActionCache: WindowActionCache,
        openCallback: @escaping (WindowAction) -> (),
        closeCallback: @escaping (Bool) -> (),
        checkIfLoopOpen: @escaping () -> Bool
    ) {
        self.windowActionCache = windowActionCache
        self.openCallback = openCallback
        self.closeCallback = closeCallback
        self.checkIfLoopOpen = checkIfLoopOpen
    }

    func start() async {
        guard await AccessibilityManager.shared.isGranted else {
            return
        }

        eventMonitor?.stop()

        let eventMonitor = ActiveEventMonitor(
            "keybind_trigger",
            events: [.keyDown, .keyUp, .flagsChanged]
        ) { [weak self] event -> ActiveEventMonitor.EventHandling in
            guard let self else { return .forward }

            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                .baseKey(flags: .init(rawValue: UInt(event.flags.rawValue)))

            var filteredFlags = event.flags
            if keyCode.isFnSpecialKey, !effectiveEventFlags.contains(.maskSecondaryFn) {
                filteredFlags.remove(.maskSecondaryFn)
            }

            let isLoopOpen = checkIfLoopOpen()
            effectiveEventFlags = filteredFlags

            if event.type == .keyUp {
                pressedKeys.remove(keyCode)
            } else if event.type == .keyDown {
                pressedKeys.insert(keyCode)
            }

            // Special events such as the emoji key
            if specialEventKeys.contains(keyCode) {
                let canPassthrough = canPassthroughNextSpecialEvent
                canPassthroughNextSpecialEvent = true // reset
                return canPassthrough ? .forward : .ignore
            }

            // If this is a valid event, don't passthrough
            let result = performKeybind(
                type: event.type,
                isARepeat: event.getIntegerValueField(.keyboardEventAutorepeat) == 1,
                flags: filteredFlags,
                isLoopOpen: isLoopOpen
            )

            if result == .consume {
                log.debug("Blocked event")
                return .ignore
            }

            // If this shouldn't consume the event, and Loop isn't in the process of opening (possibly due to trigger delays),
            // check if it was a system keybind (ex. screenshot), and in that case, passthrough and force-close Loop
            refreshSystemKeybindCacheIfNeeded()
            if result != .opening, event.type == .keyDown, systemKeybindCache.contains(pressedKeys) {
                closeLoop(forceClose: true)
            }

            return .forward
        }

        eventMonitor.start()
        self.eventMonitor = eventMonitor
    }

    func stop() {
        eventMonitor?.stop()
        eventMonitor = nil

        // Reset states
        pressedKeys = []
        canPassthroughNextSpecialEvent = true
    }

    enum PerformKeybindResult {
        case consume
        case forward
        case opening
    }

    /// Determines if an event corresponds to a valid Loop action.
    /// - Parameters:
    ///   - type: the type of this event.
    ///   - isARepeat: whether this event is a repeat event.
    ///   - flags: modifier flags associated with this event.
    ///   - isLoopOpen: whether Loop is currently open.
    /// - Returns: whether this event was processed by Loop.
    private func performKeybind(type: CGEventType, isARepeat: Bool, flags: CGEventFlags, isLoopOpen: Bool) -> PerformKeybindResult {
        let flagKeys = sideDependentTriggerKey ? flags.keyCodes : flags.keyCodes.baseModifiers
        let allPressedKeys: Set<CGKeyCode> = pressedKeys.union(flagKeys)

        let containsTrigger = allPressedKeys.isSuperset(of: triggerKey)
        let actionKeys: Set<CGKeyCode> = Set(allPressedKeys.subtracting(triggerKey).map(\.baseModifier))
        let allPressedKeysBaseModifiers: Set<CGKeyCode> = Set(allPressedKeys.map(\.baseModifier))

        if isLoopOpen {
            if pressedKeys.contains(.kVK_Escape) {
                closeLoop(forceClose: true)
                return .consume
            }

            if type == .keyUp {
                return .forward
            }

            if type != .keyDown, !containsTrigger {
                closeLoop(forceClose: false)
                return .forward
            }
        }

        if type != .keyUp { // keyDown for flagsChanged
            if containsTrigger {
                // Try an match directly with the action keys first, then fallback to just the key code.
                // This prevents failures when the user is tapping the keys in rapid succession.
                if let action = windowActionCache.actionsByKeybind[actionKeys] {
                    if !isARepeat || action.canRepeat {
                        openLoop(startingAction: action, overrideExistingTriggerDelayTimerAction: true)
                    }

                    // Only consume the event if the last command actually opened Loop.
                    // The main reason Loop *wouldn't* open after an `openLoop` call would be because the user has enabled a trigger delay.
                    return checkIfLoopOpen() ? .consume : .opening
                }

                // Only trigger Loop without an action if the only pressed keys perfectly matches the trigger key.
                if allPressedKeys == triggerKey {
                    openLoop(
                        startingAction: .init(.noSelection),
                        overrideExistingTriggerDelayTimerAction: !isARepeat
                    )
                    return .opening
                }
            } else if let bypassedAction = windowActionCache.bypassedActionsByKeybind[allPressedKeysBaseModifiers] {
                if !isARepeat || bypassedAction.canRepeat {
                    openLoop(startingAction: bypassedAction, overrideExistingTriggerDelayTimerAction: true)
                }

                return checkIfLoopOpen() ? .consume : .opening
            } else {
                if allPressedKeys.isEmpty {
                    doubleClickTimer.handleKeyUp()
                }
                closeLoop(forceClose: false)
            }
        }

        // If this wasn't a valid keybind, return false, which will then forward the key event to the frontmost app
        return .forward
    }

    private func openLoop(startingAction: WindowAction, overrideExistingTriggerDelayTimerAction: Bool) {
        if checkIfLoopOpen() {
            openCallback(startingAction) // Only update Loop to the latest WindowAction
        } else {
            if doubleClickToTrigger {
                doubleClickTimer.handleKeyDown(startingAction: startingAction)
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
        triggerDelayTimer.cancel()
        closeCallback(forceClose)
        pressedKeys = []
    }

    private func startTriggerDelayTimer(
        startingAction: WindowAction,
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

    private func refreshSystemKeybindCacheIfNeeded() {
        let shouldRefresh: Bool = if let keybindCacheUpdatedAt {
            keybindCacheUpdatedAt.duration(to: .now) > keybindCacheLifetime
        } else {
            true
        }

        guard shouldRefresh else {
            return
        }

        systemKeybindCache = CGKeyCode.systemKeybinds
        keybindCacheUpdatedAt = .now
    }
}
