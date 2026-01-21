//
//  ResizeContext.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-19.
//

import Scribe
import SwiftUI

// MARK: - ComputedFrame

extension ResizeContext {
    /// Holds both the raw (non-padded) and padded target frames for a resize operation.
    struct ComputedFrame: Equatable {
        /// The frame calculated without any padding applied.
        var raw: CGRect

        /// The frame with padding applied (outer bounds padding + inner window padding).
        /// When no padding is configured, this equals `raw`.
        var padded: CGRect

        static let zero = ComputedFrame(raw: .zero, padded: .zero)

        init(raw: CGRect, padded: CGRect) {
            self.raw = raw
            self.padded = padded
        }

        /// Creates a ComputedFrame where both raw and padded are the same (no padding case).
        init(_ frame: CGRect) {
            self.raw = frame
            self.padded = frame
        }
    }
}

// MARK: - ResizeContext

/// Holds transient state for a window resize operation.
/// This context tracks the target frame and which edges to adjust during grow/shrink actions,
/// along with the window, screen, and bounds information needed to compute frames.
@Loggable
struct ResizeContext {
    private(set) var window: Window?
    var targetFrame: ComputedFrame = .zero

    private(set) var screen: NSScreen?
    private(set) var bounds: CGRect
    private(set) var padding: PaddingConfiguration = .zero

    private(set) var action: WindowAction = .init(.noSelection)
    private(set) var parentAction: WindowAction?

    var sidesToAdjust: Edge.Set?
    private(set) var initialMousePosition: CGPoint = .zero

    private init(
        window: Window?,
        targetFrame: ComputedFrame,
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
            targetFrame: ComputedFrame(initialFrame),
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
        let initialFrame = window?.frame ?? .zero
        return ResizeContext(
            window: window,
            targetFrame: ComputedFrame(initialFrame),
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
        let initialFrame = window?.frame ?? .zero
        return ResizeContext(
            window: window,
            targetFrame: ComputedFrame(initialFrame),
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
        let rawFrame = action.getFrame(
            window: nil,
            bounds: bounds
        ).raw

        return ResizeContext(
            window: nil,
            targetFrame: ComputedFrame(rawFrame),
            screen: nil,
            bounds: bounds,
            padding: .zero,
            action: action,
            parentAction: parentAction,
            initialMousePosition: .zero
        )
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

        let result = action.getFrame(resizeContext: self)
        let rawFrame = result.frame.raw
        sidesToAdjust = result.sidesToAdjust

        // Apply padding if configured
        let paddedFrame = if padding != .zero {
            padding.apply(to: rawFrame, bounds: bounds, action: action, window: window)
        } else {
            rawFrame
        }

        targetFrame = ComputedFrame(raw: rawFrame, padded: paddedFrame)
        log.info("Cached target frame - padded: \(targetFrame.padded), raw: \(targetFrame.raw) for action: \(action)")
    }
}
