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
    private var lastTriggerKeyReleaseTime: Date?
    private let openCallback: (WindowAction) -> ()
    private var doubleClickInterval: TimeInterval = 0.5

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

        lastTriggerKeyReleaseTime = nil
    }

    /// Handles a key up event.
    /// Updates the last trigger time without firing the callback.
    func handleKeyUp() {
        lastTriggerKeyReleaseTime = Date()
    }
}
