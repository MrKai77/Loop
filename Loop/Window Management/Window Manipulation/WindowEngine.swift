//
//  WindowEngine.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-16.
//

import Defaults
import Scribe
import SwiftUI

/// This enum handles the execution of `WindowAction`s on windows within the user's workspace.
enum WindowEngine {
    /// Resize a Window
    /// - Parameters:
    ///   - window: Window to be resized
    ///   - action: WindowAction to resize the window to
    ///   - screen: Screen the window should be resized on
    ///   - shouldRecord: only set to false when preview window is disabled (so live preview)
    static func resize(
        _ window: Window,
        to action: WindowAction,
        on screen: NSScreen,
        shouldRecord: Bool = true
    ) {
        guard action.direction != .noAction, action.direction != .noSelection, !action.direction.willFocusWindow else { return }

        let willChangeScreens = ScreenUtility.screenContaining(window) != screen

        let windowTitle = window.nsRunningApplication?.localizedName ?? window.title ?? "<unknown>"
        Log.info("Resizing \(windowTitle) to \(action.direction.debugDescription) on \(screen.localizedName)", category: .windowEngine)

        // Before commiting to anything, we should record the action.
        // This allows the user to undo any one of their actions.
        if shouldRecord {
            WindowRecords.record(window, action)
        }

        // If the action is to hide, minimize or fullscreen perform the action then return
        if action.direction == .hide {
            window.toggleHidden()
            return
        }

        if action.direction == .minimize {
            window.toggleMinimized()
            return
        }

        if action.direction == .fullscreen {
            window.toggleFullscreen()
            return
        }

        // If the action is minimizeOthers, we don't need to actually perform any actions on the window itself.
        // So after minimizing other windows, we should simply return.
        if action.direction == .minimizeOthers {
            minimizeOtherWindows(exceptWindow: window)
            return
        }

        // Note that this is only really useful when "Resize window under cursor" is enabled
        if Defaults[.focusWindowOnResize] {
            window.activate()
        }

        // Use the system window manager if it has been set by the user.
        // Note that we don't use it when switching screens, as the system window manager doesn't support that.
        if !willChangeScreens,
           #available(macOS 15, *),
           Defaults[.useSystemWindowManagerWhenAvailable],
           resizeWithSystemWindowManager(window: window, to: action) {
            // If the preview wasn't visible, then that means that this is the new live frame.
            if !Defaults[.previewVisibility] {
                LoopManager.lastTargetFrame = window.frame
            }
        } else {
            // Otherwise, we obviously need to disable fullscreen to resize the window
            window.fullscreen = false

            // Calculate the target frame
            let targetFrame: CGRect = action.getFrame(
                window: window,
                bounds: screen.safeScreenFrame,
                screen: screen
            )
            Log.info("Target window frame: \(targetFrame.debugDescription)", category: .windowEngine)

            // If the action is undo, remove the last action from the window records.
            if action.direction == .undo {
                WindowRecords.removeLastAction(for: window)
            }

            // If the window is one of Loop's windows, resize it using the actual NSWindow, preventing crashes
            if window.nsRunningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
                resizeOwnWindow(targetFrame: targetFrame)
            } else {
                let shouldAnimate = shouldAnimateResize(
                    for: window,
                    willChangeScreens: willChangeScreens
                )
                resizeWindow(
                    window,
                    targetFrame: targetFrame,
                    screen: screen,
                    willChangeScreens: willChangeScreens,
                    ignorePadding: action.direction.willMove,
                    animate: shouldAnimate
                )
            }

            // Move cursor to center of window if user has enabled it
            if Defaults[.moveCursorWithWindow] {
                CGWarpMouseCursorPosition(targetFrame.center)
            }
        }

        StashManager.shared.onWindowResized(
            action: action,
            window: window,
            screen: screen
        )
    }

    /// Resize a window using the system window manager, if available (macOS 15+)
    /// - Parameters:
    ///   - window: Window to be resized
    ///   - action: WindowDirection to resize the window to
    /// - Returns: Whether the action was performed successfully
    @available(macOS 15, *)
    private static func resizeWithSystemWindowManager(
        window: Window,
        to action: WindowAction
    ) -> Bool {
        guard
            let systemAction = action.direction.systemEquivalent, // Ensure that there's a system equivalent action for the desired action
            let app = window.nsRunningApplication, // Ensure that we can get the app's NSRunningApplication and that it's frontmost
            app == NSWorkspace.shared.frontmostApplication,
            let axMenuItem = try? systemAction.getItem(for: app), // Try and get the AXMenuItem for the action
            (try? axMenuItem.getValue(.enabled)) == true // Ensure that the action is enabled (e.g. "Zoom" is disabled for size-constrained windows)
        else {
            Log.info("System action not available for \(action.direction.debugDescription) on \(window.title ?? "<unknown>")", category: .windowEngine)
            return false
        }

        try? axMenuItem.performAction(.press)
        return true
    }

    /// Determines if a window resize should be animated by Loop or not.
    /// Note that this does not affect the system window manager.
    /// - Parameter window: The window to be resized
    /// - Returns: Whether the window should be animated or not
    private static func shouldAnimateResize(for window: Window, willChangeScreens: Bool) -> Bool {
        // If enhancedUI is enabled, then window animations will likely lag a LOT. So, if it's enabled, force-disable animations
        if window.enhancedUserInterface {
            return false
        }

        // If the user has enabled the system window manager, then return the system's animation setting
        // Note that this is only if we're not changing screens. Otherwise, it ends up looking a little glitchy at the moment.
        if !willChangeScreens, #available(macOS 15, *), Defaults[.useSystemWindowManagerWhenAvailable] {
            return SystemWindowManager.MoveAndResize.enableAnimations
        }

        // If the user has disabled window animations, then return false
        if !Defaults[.animateWindowResizes] {
            return false
        }

        // If the user has enabled low power mode and hasn't set the preference to ignore it, then return false
        if ProcessInfo.processInfo.isLowPowerModeEnabled, !Defaults[.ignoreLowPowerMode] {
            return false
        }

        return true
    }

    private static func resizeOwnWindow(targetFrame: CGRect) {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: {
            $0.level.rawValue <= NSWindow.Level.floating.rawValue
        }) else {
            Log.info("Failed to get own main window to resize", category: .windowEngine)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.33, 1, 0.68, 1)
            window.animator().setFrame(targetFrame.flipY(screen: .screens[0]), display: false)
        }
    }

    private static func resizeWindow(
        _ window: Window,
        targetFrame: CGRect,
        screen: NSScreen,
        willChangeScreens: Bool,
        ignorePadding: Bool,
        animate: Bool
    ) {
        let respectsPaddingThreshold = Defaults[.paddingMinimumScreenSize] == 0 || screen.diagonalSize > Defaults[.paddingMinimumScreenSize]
        let usePadding = PaddingSettings.enablePadding && respectsPaddingThreshold

        // Grab the bounds of the screen, with padding applied. This is generally not needed, except for:
        // - when window animations are enabled, we use the bounds to keep the window on-screen
        // - when the window finishes resizing, we move the window into the bounds if needed
        let bounds = if ignorePadding {
            // If the window is being moved via shortcuts (move right, move left etc.), then the bounds will be zero.
            // This is because the window *can* be moved off-screen in this case.
            CGRect.zero
        } else if usePadding {
            PaddingSettings.padding.apply(on: screen.safeScreenFrame)
        } else {
            screen.safeScreenFrame
        }

        window.setFrame(
            targetFrame,
            animate: animate,
            sizeFirst: willChangeScreens,
            bounds: bounds
        ) {
            // Fixes an issue where window isn't resized correctly on multi-monitor setups
            // If window is being animated, then the size is very likely to already be correct, as what's really happening is window.setFrame at a really high rate.
            if !animate, !window.frame.approximatelyEqual(to: targetFrame) {
                window.setFrame(targetFrame)
            }

            // If window's minimum size exceeds the screen bounds, push it back in
            WindowEngine.handleSizeConstrainedWindow(window: window, bounds: bounds)
        }
    }

    /// Will move a window back onto the screen. To be run AFTER a window has been resized.
    /// - Parameters:
    ///   - window: The window to handle size constraints for
    ///   - screenFrame: The screen's frame
    private static func handleSizeConstrainedWindow(window: Window, bounds: CGRect) {
        guard bounds != .zero else {
            return
        }

        var windowFrame = window.frame

        // If the window is fully shown on the screen
        if windowFrame.maxX <= bounds.maxX,
           windowFrame.maxY <= bounds.maxY {
            return
        }

        if windowFrame.maxX > bounds.maxX {
            windowFrame.origin.x = bounds.maxX - windowFrame.width
        }

        if windowFrame.maxY > bounds.maxY {
            windowFrame.origin.y = bounds.maxY - windowFrame.height
        }

        window.position = windowFrame.origin
    }

    /// Minimizes all windows except the current one
    private static func minimizeOtherWindows(exceptWindow: Window) {
        let allWindows = WindowUtility.windowList()
        let windowsToMinimize = allWindows.filter { otherWindow in
            // Don't minimize the current window
            guard otherWindow.cgWindowID != exceptWindow.cgWindowID else { return false }

            // Only minimize windows that are not already minimized or hidden
            guard !otherWindow.minimized, !otherWindow.isWindowHidden else { return false }

            return true
        }

        Log.info("Minimizing \(windowsToMinimize.count) other windows", category: .windowEngine)

        // Minimize all other windows
        for window in windowsToMinimize {
            window.minimized = true
        }
    }
}
