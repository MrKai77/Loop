//
//  DoubleClickTimer.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-27.
//

import AppKit
import Defaults

/// A utility class that detects double-click (double-press) events within a specified time interval.
///
/// It tracks the timing of successive trigger actions (such as key presses) and determines whether
/// two occur within the system-defined (and user-customizable) `NSEvent.doubleClickInterval`.
final class DoubleClickTimer {
    private var lastTriggerKeyPressTime: Date?
    private let openCallback: (WindowAction?) -> ()
    private var doubleClickInterval: TimeInterval { NSEvent.doubleClickInterval }

    /// Creates a new `DoubleClickTimer` instance with the specified callback to invoke on a double-press event.
    /// - Parameter openCallback: A closure that is called when a double-click is detected. The closure receives the `WindowAction` associated with the trigger as its parameter.
    init(openCallback: @escaping (WindowAction?) -> ()) {
        self.openCallback = openCallback
    }

    /// Handles a trigger event (such as a key press) and determines whether it qualifies as a "double-click".
    /// - Parameter startingAction: The `WindowAction` associated with the trigger.
    func handleTrigger(startingAction: WindowAction?) {
        let now = Date()

        // If we detect a double-press, trigger immediately. Otherwise, just record the time
        if let last = lastTriggerKeyPressTime, now.timeIntervalSince(last) < doubleClickInterval {
            openCallback(startingAction)
            lastTriggerKeyPressTime = nil
        } else {
            lastTriggerKeyPressTime = now
        }
    }
}
