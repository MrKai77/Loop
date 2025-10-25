//
//  MiddleClickObserver.swift
//  Loop
//
//  Created by Kai Azim on 2025-08-29.
//

import AppKit
import Defaults

/// Reads middle-click events using a PassiveEventMonitor, and triggers Loop open/close callbacks, when appropriate.
final class MiddleClickObserver {
    // Callbacks
    private let openCallback: () -> ()
    private let closeCallback: () -> ()

    // State-tracking
    private var monitor: PassiveEventMonitor?
    private var triggerDelayTimer: Task<(), Never>?

    // Defaults
    private var middleClickTriggersLoop: Bool { Defaults[.middleClickTriggersLoop] }
    private var useTriggerDelay: Bool { Defaults[.enableTriggerDelayOnMiddleClick] && Defaults[.triggerDelay] > 0.1 }
    private var triggerDelay: TimeInterval { Defaults[.triggerDelay] }

    /// Initializes a ``MiddleClickObserver``.
    /// - Parameters:
    ///   - openCallback: what to do when the trigger key is pressed, and Loop should be activated.
    ///   - closeCallback: what to do when the trigger key is released, and Loop should be closed.
    init(
        openCallback: @escaping (WindowAction?) -> (),
        closeCallback: @escaping () -> ()
    ) {
        // We will never start off with an action from this trigger, so pass in nil
        self.openCallback = { openCallback(nil) }
        self.closeCallback = closeCallback
    }

    @MainActor
    func start() {
        stop()

        let monitor = PassiveEventMonitor(
            events: [.otherMouseDown, .otherMouseUp],
            callback: handleOtherMouseKeypress
        )
        monitor.start()

        self.monitor = monitor
    }

    @MainActor
    func stop() {
        monitor?.stop()
        monitor = nil
    }

    // MARK: Private

    private func handleOtherMouseKeypress(_ event: CGEvent) {
        Task { @MainActor in
            guard middleClickTriggersLoop else {
                return
            }

            if event.type == .otherMouseDown,
               event.getIntegerValueField(.mouseEventButtonNumber) == 2 {
                if useTriggerDelay {
                    startTriggerDelayTimer()
                } else {
                    openCallback()
                }
            } else {
                triggerDelayTimer?.cancel()
                closeCallback()
            }
        }
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
}
