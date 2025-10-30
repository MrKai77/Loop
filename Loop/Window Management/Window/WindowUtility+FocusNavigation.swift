//
//  WindowUtility+FocusNavigation.swift
//  Loop
//
//  Created by cipher-shad0w on 2025-10-30.
//

import AppKit
import OSLog

extension WindowUtility {
    private static let focusLogger = Logger(category: "WindowUtility+FocusNavigation")

    /// Finds the next window to focus in the specified direction.
    /// - Parameters:
    ///   - currentWindow: The currently focused window to navigate from
    ///   - direction: The direction to search for the next window (focusUp, focusDown, focusLeft, focusRight)
    /// - Returns: The next window in the specified direction, or `nil` if no suitable window is found
    static func nextWindow(from currentWindow: Window, in direction: WindowDirection) -> Window? {
        // Get the edge direction for focus navigation
        guard let edge = direction.focusEdge else {
            focusLogger.error("Invalid direction for focus navigation: \(direction.debugDescription)")
            return nil
        }

        let allWindows = windowList()

        // Filter out the current window and get only visible, non-minimized, non-excluded windows
        let otherWindows = allWindows.filter { window in
            window.cgWindowID != currentWindow.cgWindowID &&
                !window.minimized &&
                !window.isWindowHidden &&
                !window.isAppExcluded
        }

        guard !otherWindows.isEmpty else {
            focusLogger.info("No other windows available to focus")
            return nil
        }

        // Use the generic directional navigation from ScreenUtility
        if let nextWindow = ScreenUtility.directionalItem(
            from: currentWindow,
            in: otherWindows,
            edge: edge,
            canRestartCycle: true,
            frameProvider: { $0.frame }
        ) {
            let nextWindowName = nextWindow.nsRunningApplication?.localizedName ?? nextWindow.title ?? "<unknown>"
            focusLogger.info("Found window to focus in direction \(direction.debugDescription): \(nextWindowName)")
            return nextWindow
        } else {
            focusLogger.info("No window found in direction \(direction.debugDescription)")
            return nil
        }
    }
}
