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

            if keyCode.isArrowKey || keyCode.isFKey, !previousEventFlags.contains(.maskSecondaryFn) {
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
        let triggerKey: Set<CGKeyCode> = Defaults[.triggerKey]

        let allPressedKeys: Set<CGKeyCode> = pressedKeys.union(flags.keyCodes)
        let actionKeys: Set<CGKeyCode> = allPressedKeys.subtracting(triggerKey)
        let containsTrigger = allPressedKeys.isSuperset(of: triggerKey)

        if checkIfLoopOpen() {
            if pressedKeys.contains(.kVK_Escape) {
                pressedKeys = []
                canPassthroughSpecialEvents = true

                closeCallback(true)
                return true
            }

            if type == .keyUp {
                // Ignore key-up events occurring within 100ms of each other.
                // Prevents direction changes when rapidly (normally) releasing multiple pressed keys.
                if abs(lastKeyReleaseTime.timeIntervalSinceNow) > 0.1 {
                    lastKeyReleaseTime = Date.now
                }

                return true
            }

            if type != .keyDown, !containsTrigger {
                closeCallback(false)
                return true
            }
        }

        if type != .keyUp, containsTrigger {
            if let action = actionsByKeybindCache[actionKeys], !isARepeat || action.willManipulateExistingWindowFrame {
                openCallback(action)
                return true
            } else {
                openCallback(nil)
                return false
            }
        }

        // If this wasn't a valid keybind, return false, which will then forward the key event to the frontmost app
        return false
    }
}
