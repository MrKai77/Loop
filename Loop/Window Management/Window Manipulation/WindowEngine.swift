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
    static func performResize(context: ResizeContext) async throws {
        // Immediately return for no-op or focus-only actions
        guard let window = context.window,
              !context.action.direction.isNoOp,
              !context.action.direction.willFocusWindow
        else {
            return
        }

        // Quick actions are handled by WindowActionEngine
        let quickActions: [WindowDirection] = [.hide, .minimize, .fullscreen, .minimizeOthers]
        guard !quickActions.contains(context.action.direction) else { return }

        if context.resolvedWindowProperties == nil {
            await context.refreshResolvedState()
        }

        let willChangeScreens = ScreenUtility.screenContaining(window) != context.screen
        let targetFrame = context.getTargetFrame().padded
        log.info("Resizing \(window) to \(targetFrame)")

        // Record first frame if needed
        await WindowRecords.shared.recordFirstIfNeeded(
            for: window,
            resolvedProperties: context.resolvedWindowProperties
        )

        let storeAsFrame = WindowRecords.shared.shouldStoreAsFinalFrame(context.action)

        // If this action doesn't require storage as a frame, then record it beforehand.
        // Otherwise, this action will be recorded *after* resizing, such that its final frame is considered if undoing.
        if !storeAsFrame {
            await WindowRecords.shared.record(
                window,
                resolvedProperties: context.resolvedWindowProperties,
                context.action
            )
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
           await resizeWithSystemWindowManager(window: window, to: context.action) {
        } else {
            if context.resolvedWindowProperties?.isFullscreen ?? true {
                // Otherwise, we obviously need to disable fullscreen to resize the window
                window.fullscreen = false
            }

            let shouldAnimate = shouldAnimateResize(
                for: window,
                willChangeScreens: willChangeScreens,
                resolvedProperties: context.resolvedWindowProperties
            )

            do {
                try await resizeWindow(
                    window,
                    targetFrame: targetFrame,
                    bounds: context.paddedBounds,
                    willChangeScreens: willChangeScreens,
                    animate: shouldAnimate,
                    resolvedProperties: context.resolvedWindowProperties
                )
            } catch {
                log.error(error.localizedDescription)
            }

            if Defaults[.moveCursorWithWindow] {
                CGWarpMouseCursorPosition(targetFrame.center)
            }
        }

        // Record post-resize actions (replaces former defer block)
        if context.action.direction == .undo {
            await WindowRecords.shared.removeLastAction(for: window)
        } else if storeAsFrame {
            // Pass nil for resolvedProperties so that record() reads the "live"
            // post-resize frame via window.frame, rather than the stale
            // pre-resize snapshot.
            await WindowRecords.shared.record(
                window,
                resolvedProperties: nil,
                context.action
            )
        }

        // Update the snapshot
        let actualFrame = window.frame
        if let existing = context.resolvedWindowProperties {
            context.resolvedWindowProperties = Window.ResolvedProperties(
                updating: actualFrame,
                from: existing
            )
        }
        context.lastAppliedFrame = actualFrame
        context.resolvedRecord = await WindowRecords.ResolvedRecord(for: window)

        if let screen = context.screen {
            await StashManager.shared.onWindowResized(
                action: context.action,
                window: window,
                screen: screen
            )
        }
    }

    // MARK: - System Window Manager

    @available(macOS 15, *)
    private static func resizeWithSystemWindowManager(
        window: Window,
        to action: WindowAction
    ) async -> Bool {
        var action = action

        if action.direction == .undo, let lastAction = await WindowRecords.shared.getLastAction(for: window) {
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

    private static func shouldAnimateResize(
        for window: Window,
        willChangeScreens: Bool,
        resolvedProperties: Window.ResolvedProperties?
    ) -> Bool {
        if resolvedProperties?.isEnhancedUserInterface ?? window.enhancedUserInterface { return false }
        if !willChangeScreens, #available(macOS 15, *), Defaults[.useSystemWindowManagerWhenAvailable] {
            return SystemWindowManager.MoveAndResize.enableAnimations
        }
        if !Defaults[.animateWindowResizes] { return false }
        if ProcessInfo.processInfo.isLowPowerModeEnabled, !Defaults[.ignoreLowPowerMode] { return false }
        return true
    }

    // MARK: - Window Resize

    private static func resizeWindow(
        _ window: Window,
        targetFrame: CGRect,
        bounds: CGRect,
        willChangeScreens: Bool,
        animate: Bool,
        resolvedProperties: Window.ResolvedProperties? = nil
    ) async throws {
        if animate {
            try await window.setFrameAnimated(targetFrame, bounds: bounds, resolvedProperties: resolvedProperties)
        } else {
            await window.setFrame(targetFrame, sizeFirst: willChangeScreens, resolvedProperties: resolvedProperties)
            try Task.checkCancellation()
        }

        if !animate, !window.frame.approximatelyEqual(to: targetFrame) {
            await window.setFrame(targetFrame, resolvedProperties: resolvedProperties)
            try Task.checkCancellation()
        }

        handleSizeConstrainedWindow(window: window, targetFrame: targetFrame, bounds: bounds)
    }

    // MARK: - Size Constraints

    private static func handleSizeConstrainedWindow(window: Window, targetFrame: CGRect, bounds: CGRect) {
        guard !window.isOwnWindow, bounds != .zero else { return }

        var windowFrame = window.frame
        let targetEdges = targetFrame.getEdgesTouchingBounds(bounds)

        // Some windows have size constraints such as fixed aspect ratios, fixed width,
        // fixed height, etc. When that happens, preserve the intended anchor by
        // re-positioning the resulting frame after the resize completes.
        if !windowFrame.size.approximatelyEqual(to: targetFrame.size, tolerance: 2) {
            windowFrame = anchoredFrame(
                for: windowFrame.size,
                within: targetFrame,
                targetEdges: targetEdges,
                bounds: bounds
            )
        }

        window.setPosition(windowFrame.origin)
    }

    static func anchoredFrame(
        for actualSize: CGSize,
        within requestedFrame: CGRect,
        targetEdges: Edge.Set,
        bounds: CGRect
    ) -> CGRect {
        var frame = CGRect(origin: requestedFrame.origin, size: actualSize)

        if targetEdges.contains(.leading), targetEdges.contains(.trailing) {
            frame.origin.x = requestedFrame.midX - actualSize.width / 2
        } else if targetEdges.contains(.leading) {
            frame.origin.x = requestedFrame.minX
        } else if targetEdges.contains(.trailing) {
            frame.origin.x = requestedFrame.maxX - actualSize.width
        } else {
            frame.origin.x = requestedFrame.midX - actualSize.width / 2
        }

        if targetEdges.contains(.top), targetEdges.contains(.bottom) {
            frame.origin.y = requestedFrame.midY - actualSize.height / 2
        } else if targetEdges.contains(.top) {
            frame.origin.y = requestedFrame.minY
        } else if targetEdges.contains(.bottom) {
            frame.origin.y = requestedFrame.maxY - actualSize.height
        } else {
            frame.origin.y = requestedFrame.midY - actualSize.height / 2
        }

        return frame.pushInside(bounds)
    }
}
