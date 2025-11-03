//
//  WindowUtility+FocusNavigation.swift
//  Loop
//
//  Created by cipher-shad0w on 2025-10-30.
//

import AppKit
import OSLog
import SwiftUI

extension WindowUtility {
    private static var navigationUtility = DirectionalNavigationUtility<Window>(frameProvider: \.frame)

    /// Focuses the next window in the specified direction.
    /// - Parameters:
    ///   - currentWindow: The currently focused window to navigate from, or nil to navigate from screen center
    ///   - direction: The direction to search for the next window (focusUp, focusDown, focusLeft, focusRight)
    static func focusWindow(from currentWindow: Window?, edge: Edge) -> Window? {
        guard let directionalWindow = WindowUtility.directionalWindow(from: currentWindow, edge: edge) else {
            logger.info("[FocusNavigation] No window found to focus in direction \(String(describing: edge))")
            return nil
        }

        let nextWindowTitle = directionalWindow.nsRunningApplication?.localizedName ?? directionalWindow.title ?? "<unknown>"
        logger.info("[FocusNavigation] Focusing window: \(nextWindowTitle)")

        directionalWindow.activate()

        return directionalWindow
    }

    /// Finds the next window to focus in the specified direction.
    /// - Parameters:
    ///   - currentWindow: The currently focused window to navigate from, or nil to navigate from screen center
    ///   - edge: The direction to search for the next window (leading, trailing, top, bottom)
    /// - Returns: The next window in the specified direction, or `nil` if no suitable window is found
    private static func directionalWindow(
        from currentWindow: Window?,
        edge: Edge
    ) -> Window? {
        let allWindows = windowList()

        // If no current window, navigate from screen center
        if currentWindow == nil {
            guard let screen = NSScreen.screenWithMouse ?? NSScreen.main else {
                logger.error("[FocusNavigation] Could not determine active screen")
                return nil
            }

            let screenCenter = screen.frame.center
            logger.info("[FocusNavigation] Navigating from screen center: (\(screenCenter.x), \(screenCenter.y))")

            // Filter to get only visible, non-minimized, non-excluded windows
            let availableWindows = allWindows.filter { window in
                !window.minimized &&
                    !window.isWindowHidden &&
                    !window.isAppExcluded
            }

            guard !availableWindows.isEmpty else {
                logger.info("[FocusNavigation] No windows available to focus")
                return nil
            }

            // Find the closest window in the specified direction from screen center
            let nextWindow = availableWindows
                .filter { window in
                    isInDirection(window.frame, from: screenCenter, edge: edge)
                }
                .min { window1, window2 in
                    screenCenter.distance(to: window1.frame.center) < screenCenter.distance(to: window2.frame.center)
                }

            if let nextWindow {
                let nextWindowName = nextWindow.nsRunningApplication?.localizedName ?? nextWindow.title ?? "<unknown>"
                logger.info("[FocusNavigation] Found window to focus in direction \(String(describing: edge)): \(nextWindowName)")
            } else {
                logger.info("[FocusNavigation] No window found in direction \(String(describing: edge)) from screen center")
            }

            return nextWindow
        }

        // Filter out the current window and get only visible, non-minimized, non-excluded windows
        let otherWindows = allWindows.filter { window in
            window.cgWindowID != currentWindow?.cgWindowID &&
                !window.minimized &&
                !window.isWindowHidden &&
                !window.isAppExcluded
        }

        guard !otherWindows.isEmpty else {
            logger.info("[FocusNavigation] No other windows available to focus")
            return nil
        }

        // Use the generic directional navigation from DirectionalNavigationUtility
        if let nextWindow = navigationUtility.directionalItem(
            from: currentWindow!,
            in: otherWindows,
            edge: edge,
            canWrap: true
        ) {
            let nextWindowName = nextWindow.nsRunningApplication?.localizedName ?? nextWindow.title ?? "<unknown>"
            logger.info("[FocusNavigation] Found window to focus in direction \(String(describing: edge)): \(nextWindowName)")
            return nextWindow
        } else {
            logger.info("[FocusNavigation] No window found in direction \(String(describing: edge))")
            return nil
        }
    }

    /// Determines if a window frame is in the specified direction from a given point.
    /// - Parameters:
    ///   - frame: The window frame to check
    ///   - point: The reference point (screen center)
    ///   - edge: The direction to check
    /// - Returns: `true` if the window is in the specified direction
    private static func isInDirection(_ frame: CGRect, from point: CGPoint, edge: Edge) -> Bool {
        let windowCenter = frame.center

        switch edge {
        case .leading: // Left
            return windowCenter.x < point.x
        case .trailing: // Right
            return windowCenter.x > point.x
        case .top: // Up
            return windowCenter.y > point.y
        case .bottom: // Down
            return windowCenter.y < point.y
        }
    }
}
