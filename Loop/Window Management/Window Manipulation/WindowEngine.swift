//
//  WindowEngine.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-16.
//

import Defaults
import Scribe
import SwiftUI

/// Handles execution of `WindowAction`s on windows within the user's workspace
enum WindowEngine {
    /// Resize a Window
    /// - Parameters:
    ///   - window: Window to be resized
    ///   - action: WindowAction to resize the window to
    ///   - screen: Screen the window should be resized on
    ///   - completion: A completion handler. To be removed once we add proper Swift Concurrency support to LoopManager.
    static func resize(
        _ window: Window,
        to action: WindowAction,
        on screen: NSScreen,
        completion: @escaping () -> () = {}
    ) {
        Task.detached(priority: .userInitiated) {
            await resize(
                window,
                to: action,
                on: screen
            )

            completion()
        }
    }

    /// Resize a Window asynchronously
    /// - Parameters:
    ///   - window: Window to resize
    ///   - action: WindowAction describing the target layout
    ///   - screen: Screen the window should be resized on
    private static func resize(
        _ window: Window,
        to action: WindowAction,
        on screen: NSScreen
    ) async {
        // Immediately return for no-op or focus-only actions
        guard action.direction != .noAction,
              action.direction != .noSelection,
              !action.direction.willFocusWindow
        else { return }

        let willChangeScreens = ScreenUtility.screenContaining(window) != screen
        Log.info("Resizing \(window) to \(action.direction) on \(screen.localizedName)", category: .windowEngine)

        // Record first frame if needed
        WindowRecords.recordFirstIfNeeded(for: window)

        // Defer recording action or undo
        defer {
            if action.direction == .undo {
                WindowRecords.removeLastAction(for: window)
            } else {
                WindowRecords.record(window, action)
            }
        }

        // Handle quick actions off the main actor
        switch action.direction {
        case .hide:
            window.toggleHidden()
            return
        case .minimize:
            window.toggleMinimized()
            return
        case .fullscreen:
            window.toggleFullscreen()
            return
        case .minimizeOthers:
            minimizeOtherWindows(exceptWindow: window)
            return
        default: break
        }

        let useSystemWM: Bool = if #available(macOS 15, *) {
            Defaults[.useSystemWindowManagerWhenAvailable]
        } else {
            false
        }

        if Defaults[.focusWindowOnResize] || useSystemWM {
            await window.focus()
        }

        // Attempt system window manager if possible
        if !willChangeScreens, useSystemWM,
           #available(macOS 15, *),
           await resizeWithSystemWindowManager(window: window, to: action) {
            if !Defaults[.previewVisibility] {
                LoopManager.lastTargetFrame = window.frame
            }
        } else {
            // Otherwise, we obviously need to disable fullscreen to resize the window
            window.fullscreen = false

            let targetFrame = action.getFrame(
                window: window,
                bounds: screen.safeScreenFrame,
                screen: screen
            )

            Log.info("Target window frame: \(targetFrame.debugDescription)", category: .windowEngine)

            if window.nsRunningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
                await resizeOwnWindow(targetFrame: targetFrame)
            } else {
                let shouldAnimate = shouldAnimateResize(for: window, willChangeScreens: willChangeScreens)

                do {
                    try await resizeWindow(
                        window,
                        targetFrame: targetFrame,
                        screen: screen,
                        willChangeScreens: willChangeScreens,
                        ignorePadding: action.direction.willMove,
                        animate: shouldAnimate
                    )
                } catch {
                    print(error)
                }

                if Defaults[.moveCursorWithWindow] {
                    CGWarpMouseCursorPosition(targetFrame.center)
                }
            }
        }

        StashManager.shared.onWindowResized(
            action: action,
            window: window,
            screen: screen
        )
    }

    // MARK: - System Window Manager

    @available(macOS 15, *)
    private static func resizeWithSystemWindowManager(
        window: Window,
        to action: WindowAction
    ) async -> Bool {
        var action = action

        if action.direction == .undo, let lastAction = WindowRecords.getLastAction(for: window) {
            action = lastAction
        }

        guard
            let systemAction = action.direction.systemEquivalent,
            let app = window.nsRunningApplication,
            app == NSWorkspace.shared.frontmostApplication,
            let axMenuItem = try? systemAction.getItem(for: app),
            (try? axMenuItem.getValue(.enabled)) == true
        else {
            Log.info("System action not available for \(action.direction.debugDescription) on \(window.title ?? "<unknown>")", category: .windowEngine)
            return false
        }

        try? axMenuItem.performAction(.press)
        return true
    }

    // MARK: - Animation Checks

    private static func shouldAnimateResize(for window: Window, willChangeScreens: Bool) -> Bool {
        if window.enhancedUserInterface { return false }
        if !willChangeScreens, #available(macOS 15, *), Defaults[.useSystemWindowManagerWhenAvailable] {
            return SystemWindowManager.MoveAndResize.enableAnimations
        }
        if !Defaults[.animateWindowResizes] { return false }
        if ProcessInfo.processInfo.isLowPowerModeEnabled, !Defaults[.ignoreLowPowerMode] { return false }
        return true
    }

    // MARK: - Window Resize

    @MainActor
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
    ) async throws {
        let bounds = ignorePadding ? .zero :
            PaddingSettings.configuredPadding(for: screen)
            .apply(onScreenFrame: screen.safeScreenFrame)

        if animate {
            try await window.setFrameAnimated(targetFrame, bounds: bounds)
        } else {
            window.setFrame(targetFrame, sizeFirst: willChangeScreens)
        }

        if !animate, !window.frame.approximatelyEqual(to: targetFrame) {
            window.setFrame(targetFrame)
        }

        handleSizeConstrainedWindow(window: window, bounds: bounds)
    }

    // MARK: - Size Constraints

    private static func handleSizeConstrainedWindow(window: Window, bounds: CGRect) {
        guard bounds != .zero else { return }

        var windowFrame = window.frame
        if windowFrame.maxX > bounds.maxX { windowFrame.origin.x = bounds.maxX - windowFrame.width }
        if windowFrame.maxY > bounds.maxY { windowFrame.origin.y = bounds.maxY - windowFrame.height }

        window.position = windowFrame.origin
    }

    // MARK: - Minimize Others

    private static func minimizeOtherWindows(exceptWindow: Window) {
        let allWindows = WindowUtility.windowList()
        let windowsToMinimize = allWindows.filter {
            $0.cgWindowID != exceptWindow.cgWindowID && !$0.minimized && !$0.isWindowHidden
        }

        Log.info("Minimizing \(windowsToMinimize.count) other windows", category: .windowEngine)

        for window in windowsToMinimize {
            window.minimized = true
        }
    }
}
