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
/// Both the press duration and the interval between presses must be within the threshold for a
/// double-click to register.
final class DoubleClickTimer {
    private var lastTriggerKeyPressTime: Date?
    private var lastTriggerKeyReleaseTime: Date?
    private let openCallback: (WindowAction) -> ()
    private var doubleClickInterval: TimeInterval {
        min(NSEvent.doubleClickInterval, 0.4) // never slower than 0.4 s
    }

    /// Creates a new `DoubleClickTimer` instance with the specified callback to invoke on a double-press event.
    /// - Parameter openCallback: A closure called when a double-press is detected. Receives the associated `WindowAction`.
    init(openCallback: @escaping (WindowAction) -> ()) {
        self.openCallback = openCallback
    }

    /// Handles a key down event.
    /// Triggers the callback if this qualifies as a double-press, otherwise records the press time.
    /// - Parameter action: The `WindowAction` associated with this key down.
    func handleKeyDown(startingAction: WindowAction) {
        let now = Date()

        if let last = lastTriggerKeyReleaseTime, now.timeIntervalSince(last) < doubleClickInterval {
            openCallback(startingAction)
        }

        lastTriggerKeyPressTime = now
        lastTriggerKeyReleaseTime = nil
    }

    /// Handles a key up event.
    /// Only records the release time if the press was quick (within doubleClickInterval).
    /// A long press cancels the double-click sequence.
    func handleKeyUp() {
        let now = Date()

        // Only consider this a valid "click" if the key was pressed quickly.
        // If the key was held for too long, don't start/continue the double-click timer.
        if let pressTime = lastTriggerKeyPressTime, now.timeIntervalSince(pressTime) < doubleClickInterval {
            lastTriggerKeyReleaseTime = now
        } else {
            lastTriggerKeyReleaseTime = nil
        }

        lastTriggerKeyPressTime = nil
    }
}
