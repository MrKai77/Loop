//
//  DoubleClickTimer.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-27.
//

import AppKit
import Defaults

final class DoubleClickTimer {
    private var lastTriggerKeyPressTime: Date?
    private let openCallback: (WindowAction?) -> ()

    private var doubleClickInterval: TimeInterval {
        NSEvent.doubleClickInterval
    }

    init(openCallback: @escaping (WindowAction?) -> ()) {
        self.openCallback = openCallback
    }

    /// Call this when a trigger action (like `open`) is requested.
    func handleTrigger(startingAction: WindowAction?) {
        let now = Date()

        if let last = lastTriggerKeyPressTime, now.timeIntervalSince(last) < doubleClickInterval {
            // Detected a double-press, trigger immediately
            openCallback(startingAction)
            lastTriggerKeyPressTime = nil // Reset to avoid triple triggering
        } else {
            // First press — record the time
            lastTriggerKeyPressTime = now
        }
    }
}
