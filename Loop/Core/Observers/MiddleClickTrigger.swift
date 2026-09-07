//
//  MiddleClickTrigger.swift
//  Loop
//
//  Created by Kai Azim on 2025-08-29.
//

import AppKit
import Defaults

/// Reads middle-click events using a PassiveEventMonitor, and triggers Loop open/close callbacks, when appropriate.
final class MiddleClickTrigger {
    // Callbacks
    private let openCallback: (WindowAction) -> ()
    private let closeCallback: (Bool) -> ()
    private let checkIfLoopOpen: () -> Bool

    private var monitor: PassiveEventMonitor?

    // Defaults
    private var middleClickTriggersLoop: Bool { Defaults[.middleClickTriggersLoop] }
    private var useTriggerDelay: Bool { Defaults[.enableTriggerDelayOnMiddleClick] && Defaults[.triggerDelay] > 0.1 }
    private var doubleClickToTrigger: Bool { Defaults[.doubleClickToTrigger] }

    private lazy var triggerDelayTimer = TriggerDelayTimer(openCallback: openCallback)
    private lazy var doubleClickTimer = DoubleClickTimer { [weak self] action in
        guard let self else { return }

        if useTriggerDelay {
            triggerDelayTimer.handleTrigger(startingAction: .init(.noSelection))
        } else {
            openCallback(action)
        }
    }

    /// Initializes a ``MiddleClickObserver``.
    /// - Parameters:
    ///   - openCallback: what to do when the middle mouse button is pressed, and Loop should be activated.
    ///   - closeCallback: what to do when the middle mouse button is released, and Loop should be closed.
    init(
        openCallback: @escaping (WindowAction) -> (),
        closeCallback: @escaping (Bool) -> (),
        checkIfLoopOpen: @escaping () -> Bool
    ) {
        // We will never start off with an action from this trigger, so pass in nil
        self.openCallback = openCallback
        self.closeCallback = closeCallback
        self.checkIfLoopOpen = checkIfLoopOpen
    }

    func start() {
        stop()

        let monitor = PassiveEventMonitor(
            "middle_click_trigger",
            events: [.otherMouseDown, .otherMouseUp],
            callback: handleOtherMouseKeypress
        )
        monitor.start()

        self.monitor = monitor
    }

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
                if doubleClickToTrigger {
                    doubleClickTimer.handleKeyDown(startingAction: .init(.noSelection))
                } else if useTriggerDelay {
                    triggerDelayTimer.handleTrigger(startingAction: .init(.noSelection))
                } else {
                    openCallback(.init(.noSelection))
                }
            } else {
                if !checkIfLoopOpen() {
                    doubleClickTimer.handleKeyUp()
                }

                triggerDelayTimer.cancel()
                closeCallback(false)
            }
        }
    }
}
//
//  RightClickWhileDraggingTrigger.swift
//  Loop
//

import AppKit
import Defaults
import Scribe

/// Reads right-click events using an ActiveEventMonitor, and triggers Loop open/close callbacks
/// if the user is currently dragging a window (as determined by WindowDragManager).
@Loggable
final class RightClickWhileDraggingTrigger {
    // Callbacks
    private let openCallback: (WindowAction) -> ()
    private let closeCallback: (Bool) -> ()
    private let checkIfLoopOpen: () -> Bool

    private var monitor: ActiveEventMonitor?

    // Defaults
    private var rightClickTriggersLoopWhileDragging: Bool { Defaults[.rightClickTriggersLoopWhileDragging] }

    /// Initializes a `RightClickWhileDraggingTrigger`.
    /// - Parameters:
    ///   - openCallback: A closure that is executed when the right mouse button is pressed while dragging, indicating Loop should be activated.
    ///   - closeCallback: A closure that is executed when the right mouse button is released, indicating Loop should be closed.
    ///   - checkIfLoopOpen: A closure that returns a Boolean value indicating whether Loop is currently open.
    init(
        openCallback: @escaping (WindowAction) -> (),
        closeCallback: @escaping (Bool) -> (),
        checkIfLoopOpen: @escaping () -> Bool
    ) {
        self.openCallback = openCallback
        self.closeCallback = closeCallback
        self.checkIfLoopOpen = checkIfLoopOpen
    }

    /// Starts the active event monitor to begin listening for right-click events.
    ///
    /// This method will stop any existing monitor before starting a new one.
    func start() {
        stop()

        let monitor = ActiveEventMonitor(
            "right_click_dragging_trigger",
            events: [.rightMouseDown, .rightMouseUp],
            callback: handleRightClick
        )
        monitor.start()

        self.monitor = monitor
    }

    /// Stops the active event monitor and stops listening for right-click events.
    func stop() {
        monitor?.stop()
        monitor = nil
    }

    // MARK: Private

    /// Processes captured right-click events and triggers Loop actions if a window is being dragged.
    /// - Parameter event: The captured `CGEvent` to process.
    /// - Returns: An `ActiveEventMonitor.EventHandling` value indicating whether the event should be forwarded to the system or ignored (swallowed).
    private func handleRightClick(_ event: CGEvent) -> ActiveEventMonitor.EventHandling {
        guard rightClickTriggersLoopWhileDragging else { return .forward }

        if event.type == .rightMouseDown {
            if WindowDragManager.shared.isDraggingWindow {
                Task { @MainActor in
                    openCallback(.init(.noSelection))
                }
                return .ignore
            }
        } else if event.type == .rightMouseUp {
            if checkIfLoopOpen() {
                Task { @MainActor in
                    closeCallback(false)
                }
                return .ignore
            }
        }

        return .forward
    }
}
