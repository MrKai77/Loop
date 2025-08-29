//
//  TriggerKeyObserver.swift
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
final class TriggerKeyObserver {
    // Callbacks
    private let openCallback: () -> ()
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

    /// Initializes a ``TriggerKeyObserver``.
    /// - Parameters:
    ///   - openCallback: what to do when the trigger key is pressed, and Loop should be activated.
    ///   - closeCallback: what to do when the trigger key is released, and Loop should be closed.
    init(
        openCallback: @escaping () -> (),
        closeCallback: @escaping () -> ()
    ) {
        self.openCallback = openCallback
        self.closeCallback = closeCallback
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
        triggerDelayTimer?.cancel()
        triggerDelayTimer = nil

        let previouslyPressedKeys = currentlyPressedKeys
        processModifiers(in: event)

        let wasKeyDown = event.type == .keyDown || currentlyPressedKeys.count > previouslyPressedKeys.count

        if wasKeyDown,
           triggerKey.isSubset(of: currentlyPressedKeys) {
            if useDoubleClickTrigger {
                // Ensure that only the trigger key was pressed, nothing else
                guard currentlyPressedKeys == triggerKey else { return event }

                if abs(lastTriggerkeyPressTime.timeIntervalSinceNow) < NSEvent.doubleClickInterval {
                    if useTriggerDelay {
                        startTriggerDelayTimer()
                    } else {
                        openCallback()
                    }
                }
            } else if useTriggerDelay {
                startTriggerDelayTimer()
            } else {
                openCallback()
            }

            lastTriggerkeyPressTime = .now
        } else {
            closeCallback()
            currentlyPressedKeys = []
        }

        return event
    }

    /// Starts a trigger delay timer, which will call the open callback after the specified delay.
    func startTriggerDelayTimer() {
        triggerDelayTimer?.cancel()

        triggerDelayTimer = Task { @MainActor in
            try? await Task.sleep(for: .seconds(triggerDelay))
            guard !Task.isCancelled else { return }
            triggerDelayTimer = nil

            openCallback()
        }
    }

    /// Processes modifier flags in the given event, updating the currently pressed keys.
    /// By default, it will try and preserve right/left modifier keys.
    /// However, if necessary, it will fallback to just using the base modifier keys.
    /// This is necessary when more than one modifier keys is pressed at the exact same time (such as when using Karabiner or HyperKey).
    func processModifiers(in event: NSEvent) {
        if event.modifierFlags.wasKeyUp {
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
