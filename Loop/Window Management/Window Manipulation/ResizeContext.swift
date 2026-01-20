//
//  ResizeContext.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-19.
//

import Scribe
import SwiftUI

// MARK: - ResizeContext

/// Holds transient state for a window resize operation.
/// This context tracks the target frame and which edges to adjust during grow/shrink actions,
/// along with the window, screen, and bounds information needed to compute frames.
@Loggable
struct ResizeContext {
    private(set) var window: Window?
    var targetFrame: CGRect = .zero

    private(set) var screen: NSScreen?
    private(set) var bounds: CGRect
    private(set) var padding: PaddingConfiguration = .zero

    private(set) var action: WindowAction = .init(.noSelection)
    private(set) var parentAction: WindowAction?

    var sidesToAdjust: Edge.Set?
    private(set) var initialMousePosition: CGPoint = .zero

    private init(
        window: Window?,
        targetFrame: CGRect,
        screen: NSScreen?,
        bounds: CGRect,
        padding: PaddingConfiguration,
        action: WindowAction,
        parentAction: WindowAction?,
        initialMousePosition: CGPoint
    ) {
        self.window = window
        self.targetFrame = targetFrame
        self.screen = screen
        self.bounds = bounds
        self.padding = padding
        self.action = action
        self.parentAction = parentAction
        self.initialMousePosition = initialMousePosition
    }

    /// Creates a blank context for starting a new resize operation (e.g., when Loop opens).
    static func blank(
        window: Window?,
        initialFrame: CGRect,
        initialMousePosition: CGPoint
    ) -> ResizeContext {
        ResizeContext(
            window: window,
            targetFrame: initialFrame,
            screen: nil,
            bounds: .zero,
            padding: .zero,
            action: .init(.noSelection),
            parentAction: nil,
            initialMousePosition: initialMousePosition
        )
    }

    /// Creates a context for a one-shot resize operation where screen is already known.
    static func forDirectResize(
        window: Window?,
        screen: NSScreen
    ) -> ResizeContext {
        let padding = PaddingConfiguration.getConfiguredPadding(for: screen)
        return ResizeContext(
            window: window,
            targetFrame: window?.frame ?? .zero,
            screen: screen,
            bounds: screen.cgSafeScreenFrame,
            padding: padding,
            action: .init(.noSelection),
            parentAction: nil,
            initialMousePosition: .zero
        )
    }

    /// Creates a context for UI previews, icon generation, and angle calculations (no screen required).
    static func forPreview(
        window: Window?,
        bounds: CGRect
    ) -> ResizeContext {
        ResizeContext(
            window: window,
            targetFrame: window?.frame ?? .zero,
            screen: nil,
            bounds: bounds,
            padding: .zero,
            action: .init(.noSelection),
            parentAction: nil,
            initialMousePosition: .zero
        )
    }

    /// Creates a context for settings window preview with a specific action.
    static func forSettingsPreview(
        action: WindowAction,
        parentAction: WindowAction?,
        bounds: CGRect
    ) -> ResizeContext {
        var context = ResizeContext(
            window: nil,
            targetFrame: .zero,
            screen: nil,
            bounds: bounds,
            padding: .zero,
            action: action,
            parentAction: parentAction,
            initialMousePosition: .zero
        )
        // Compute target frame based on bounds
        context.targetFrame = action.getFrame(
            window: nil,
            bounds: bounds,
            disablePadding: true
        ).targetFrame
        return context
    }

    mutating func setScreen(to screen: NSScreen?) {
        self.screen = screen
        bounds = screen?.cgSafeScreenFrame ?? .zero
        padding = PaddingConfiguration.getConfiguredPadding(for: screen)
    }

    mutating func setWindow(to window: Window?) {
        self.window = window
    }

    mutating func setAction(to newAction: WindowAction, parent newParentAction: WindowAction?) {
        action = newAction
        parentAction = newParentAction

        targetFrame = action.getFrame(resizeContext: self).targetFrame
        log.info("Cached new target frame: \(targetFrame) for action: \(action)")
    }
}
