//
//  TriggerKeybindObserver.swift
//  Loop
//
//  Created by Kai Azim on 2025-08-29.
//

import AppKit
import Defaults

/// This class is in charge of observing the user's pressed keys and calling the appropriate callbacks to open/close Loop.
///
/// To achieve this, it uses a NSEventMonitor to listen for key events.
/// It is important that a NSEventMonitor is used instead of a CGEventMonitor here, so that external key remappers (such as Karabiner or HyperKey) can take precedence.
final class TriggerKeybindObserver: LoopTrigger {
    // Callbacks
    private let openCallback: (WindowAction?) -> ()
    private let closeCallback: () -> ()

    // State-tracking
    private var monitor: EventMonitor?
    private var currentlyPressedKeys: Set<CGKeyCode> = []
    private var lastTriggerkeyPressTime: Date = .distantPast
    private var triggerDelayTimer: Task<(), Never>?

    // Defaults
    private var triggerKey: Set<CGKeyCode> { Defaults[.triggerKey] }
    private var useTriggerDelay: Bool { Defaults[.triggerDelay] > 0.1 }
    private var triggerDelay: TimeInterval { Defaults[.triggerDelay] }
    private var useDoubleClickTrigger: Bool { Defaults[.doubleClickToTrigger] }

    /// Initializes a ``TriggerKeybindObserver``.
    /// - Parameters:
    ///   - openCallback: what to do when the trigger key is pressed, and Loop should be activated. It takes in an optional `WindowAction` as a starting action.
    ///   - closeCallback: what to do when the trigger key is released, and Loop should be closed.
    init(
        openCallback: @escaping (WindowAction?) -> (),
        closeCallback: @escaping () -> ()
    ) {
        self.openCallback = openCallback
        self.closeCallback = closeCallback
    }

    func start() {
        start(scope: .all)
    }

    /// Starts observing key events.
    func start(scope: NSEventMonitor.Scope) {
        stop()

        monitor = NSEventMonitor(
            scope: scope,
            eventMask: [.keyUp, .keyDown, .flagsChanged],
            handler: handleKeypress
        )
        monitor?.start()
    }

    /// Stops observing key events.
    func stop() {
        monitor?.stop()
        monitor = nil
    }

    // MARK: Private

    /// Handles keypress events, and opens/closes Loop as necessary.
    private func handleKeypress(_ event: NSEvent) -> NSEvent? {
        if event.type == .keyDown || event.type == .keyUp, event.isARepeat {
            return event
        }

        triggerDelayTimer?.cancel()
        triggerDelayTimer = nil

        let previouslyPressedKeys = currentlyPressedKeys
        processModifiers(in: event)

        let wasKeyDown = event.type == .keyDown || currentlyPressedKeys.count > previouslyPressedKeys.count
        let containsTriggerKey = triggerKey.isSubset(of: currentlyPressedKeys)
        let selectedAction = WindowAction.getAction(for: currentlyPressedKeys.subtracting(triggerKey))
        let exactTriggerKeyMatch = triggerKey == currentlyPressedKeys.filter(\.isModifier)

        /// To open Loop, the latest event must have pressed a new key, and either:
        /// - be an exact match for the trigger key (no other keys pressed)
        /// - contain the trigger key, and also a valid keybind as configured in the user's keybind settings
        if wasKeyDown, exactTriggerKeyMatch || (containsTriggerKey && selectedAction != nil) {
            if useDoubleClickTrigger {
                // Ensure that only the trigger key was pressed, nothing else
                guard currentlyPressedKeys == triggerKey else { return event }

                if abs(lastTriggerkeyPressTime.timeIntervalSinceNow) < NSEvent.doubleClickInterval {
                    if useTriggerDelay {
                        startTriggerDelayTimer(selectedAction)
                    } else {
                        openCallback(selectedAction)
                    }
                }
            } else if useTriggerDelay {
                startTriggerDelayTimer(selectedAction)
            } else {
                openCallback(selectedAction)
            }

            lastTriggerkeyPressTime = .now
        } else {
            // If the user has set Loop to cycle backwards when shift is pressed, and the user has just pressed shift while Loop is open,
            // But it no longer matches the conditions of either exactly matching the trigger key or containing a valid keybind,
            // We should cycle backwards instead of closing Loop.
            if Defaults[.cycleBackwardsOnShiftPressed],
               !triggerKey.contains(.kVK_Shift),
               event.keyCode == .kVK_Shift {
                // We shouldn't close Loop, but cycle backwards instead
                return event
            }

            closeCallback()
            currentlyPressedKeys = []
        }

        return event
    }

    /// Starts a trigger delay timer, which will call the open callback after the specified delay.
    private func startTriggerDelayTimer(_ action: WindowAction?) {
        triggerDelayTimer?.cancel()

        triggerDelayTimer = Task { @MainActor in
            try? await Task.sleep(for: .seconds(triggerDelay))
            guard !Task.isCancelled else { return }
            triggerDelayTimer = nil

            openCallback(action)
        }
    }

    /// Processes modifier flags in the given event, updating the currently pressed keys.
    /// By default, it will try and preserve right/left modifier keys.
    /// However, if necessary, it will fallback to just using the base modifier keys.
    /// This is necessary when more than one modifier keys is pressed at the exact same time (such as when using Karabiner or HyperKey).
    private func processModifiers(in event: NSEvent) {
        // Event that Logi Options+ seems to send when a mouse button assigned to a keybind is released
        let nonModifierFlagsChanged = event.type == .flagsChanged && event.keyCode.isModifier == false

        if event.modifierFlags.wasKeyUp || nonModifierFlagsChanged {
            currentlyPressedKeys = []
        } else if currentlyPressedKeys.contains(event.keyCode) {
            currentlyPressedKeys.remove(event.keyCode)
        } else {
            currentlyPressedKeys.insert(event.keyCode)
        }

        // Backup system in case keys are pressed at the exact same time
        let flags = event.modifierFlags.convertToCGKeyCode()
        if flags.count != currentlyPressedKeys.count {
            for key in flags where CGKeyCode.modifierToImage.contains(where: { $0.key == key }) {
                if !currentlyPressedKeys.map(\.baseModifier).contains(key) {
                    currentlyPressedKeys.insert(key)
                }
            }
        }
    }
}
