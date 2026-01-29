//
//  WindowEngine.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-16.
//

import Defaults
import Scribe
import SwiftUI

/// Handles the low-level resize operations for windows.
/// Use `WindowActionEngine.apply()` as the main entry point for executing window actions.
@Loggable(style: .static)
enum WindowEngine {
    /// Performs the actual resize operation on a window.
    /// This is an internal method - callers should use `WindowActionEngine.apply()` instead.
    static func performResize(context: ResizeContext) async throws -> CGRect? {
        // Immediately return for no-op or focus-only actions
        guard let window = context.window,
              !context.action.direction.isNoOp,
              !context.action.direction.willFocusWindow
        else {
            return nil
        }

        // Quick actions are handled by WindowActionEngine
        let quickActions: [WindowDirection] = [.hide, .minimize, .fullscreen, .minimizeOthers]
        guard !quickActions.contains(context.action.direction) else { return nil }

        let willChangeScreens = ScreenUtility.screenContaining(window) != context.screen
        let targetFrame = context.getTargetFrame().padded
        log.info("Resizing \(window) to \(targetFrame)")

        // Record first frame if needed
        WindowRecords.recordFirstIfNeeded(for: window)

        let storeAsFrame = WindowRecords.shouldStoreAsFinalFrame(context.action)

        // If this action doesn't require storage as a frame, then record it beforehand.
        // Otherwise, this action will be recorded *after* resizing, such that its final frame is considered if undoing.
        if !storeAsFrame {
            WindowRecords.record(window, context.action)
        }

        defer {
            if context.action.direction == .undo {
                WindowRecords.removeLastAction(for: window)
            } else if storeAsFrame {
                WindowRecords.record(window, context.action)
            }
        }

        let useSystemWM: Bool = if #available(macOS 15, *) {
            Defaults[.useSystemWindowManagerWhenAvailable]
        } else {
            false
        }

        if Defaults[.focusWindowOnResize] || useSystemWM {
            await window.focus()
        }

        var systemWMFrame: CGRect?

        // Attempt system window manager if possible
        if !willChangeScreens, useSystemWM,
           #available(macOS 15, *),
           await resizeWithSystemWindowManager(window: window, to: context.action) {
            if !Defaults[.previewVisibility] {
                systemWMFrame = window.frame
            }
        } else {
            // Otherwise, we obviously need to disable fullscreen to resize the window
            window.fullscreen = false

            if window.nsRunningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
                await resizeOwnWindow(targetFrame: targetFrame)
            } else {
                let shouldAnimate = shouldAnimateResize(for: window, willChangeScreens: willChangeScreens)

                do {
                    try await resizeWindow(
                        window,
                        targetFrame: targetFrame,
                        bounds: context.bounds,
                        willChangeScreens: willChangeScreens,
                        ignorePadding: context.action.direction.willMove,
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

        if let screen = context.screen {
            StashManager.shared.onWindowResized(
                action: context.action,
                window: window,
                screen: screen
            )
        }

        return systemWMFrame
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
            log.info("System action not available for \(action.direction.debugDescription) on \(window.title ?? "<unknown>")")
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
            log.info("Failed to get own main window to resize")
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
        bounds: CGRect,
        willChangeScreens: Bool,
        ignorePadding _: Bool,
        animate: Bool
    ) async throws {
        if animate {
            try await window.setFrameAnimated(targetFrame, bounds: bounds)
        } else {
            window.setFrame(targetFrame, sizeFirst: willChangeScreens)
            try Task.checkCancellation()
        }

        if !animate, !window.frame.approximatelyEqual(to: targetFrame) {
            window.setFrame(targetFrame)
            try Task.checkCancellation()
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
}
