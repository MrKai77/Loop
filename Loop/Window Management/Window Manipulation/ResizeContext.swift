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
final class ResizeContext {
    private(set) var window: Window?

    private(set) var screen: NSScreen?
    private(set) var bounds: CGRect

    private(set) var padding: PaddingConfiguration = .zero
    private(set) var paddedBounds: CGRect

    private(set) var action: WindowAction = .init(.noSelection)
    private(set) var parentAction: WindowAction?

    /// Used for larger/smaller actions where the sides to adjust need to persist across frame calculations
    var sidesToAdjust: Edge.Set?

    /// Used to open radial menu at the correct position.
    private(set) var initialMousePosition: CGPoint = .zero

    private(set) var cachedTargetFrame: ComputedFrame = .zero
    private var needsRecompute: Bool = false

    init(
        window: Window? = nil,
        initialFrame: CGRect? = nil,
        screen: NSScreen? = nil,
        bounds: CGRect? = nil,
        action: WindowAction = .init(.noSelection),
        parentAction: WindowAction? = nil,
        initialMousePosition: CGPoint = .zero
    ) {
        let frame = initialFrame ?? window?.frame ?? .zero
        let bounds = bounds ?? screen?.cgSafeScreenFrame ?? .zero
        let padding = PaddingConfiguration.getConfiguredPadding(for: screen)

        self.window = window
        self.cachedTargetFrame = ComputedFrame(raw: frame, padded: frame)
        self.screen = screen
        self.bounds = bounds
        self.padding = padding
        self.paddedBounds = padding.applyToBounds(bounds)
        self.action = action
        self.parentAction = parentAction
        self.initialMousePosition = initialMousePosition
        self.needsRecompute = !action.direction.isNoOp
    }

    func setScreen(to screen: NSScreen?) {
        self.screen = screen
        bounds = screen?.cgSafeScreenFrame ?? .zero
        padding = PaddingConfiguration.getConfiguredPadding(for: screen)
        paddedBounds = padding.applyToBounds(bounds)
        needsRecompute = true
    }

    func setWindow(to window: Window?) {
        self.window = window
        needsRecompute = true

        log.info("Set window to \(window?.description ?? "nil")")
    }

    func setAction(to newAction: WindowAction, parent newParentAction: WindowAction?) {
        action = newAction
        parentAction = newParentAction
        needsRecompute = true
    }

    func getTargetFrame() -> ComputedFrame {
        if needsRecompute {
            recomputeTargetFrame()
        }

        return cachedTargetFrame
    }

    private func recomputeTargetFrame() {
        let result = WindowFrameResolver.getFrame(resizeContext: self)

        let rawFrame = result.frame
        let paddedFrame = padding.applyToWindow(
            frame: rawFrame,
            paddedBounds: paddedBounds,
            action: action,
            window: window
        )

        cachedTargetFrame = ComputedFrame(raw: rawFrame, padded: paddedFrame)
        needsRecompute = false
        log.info("Computed target frame - padded: \(cachedTargetFrame.padded), raw: \(cachedTargetFrame.raw) for action: \(action)")
    }
}

// MARK: - ComputedFrame

extension ResizeContext {
    /// Holds both the raw (non-padded) and padded target frames for a resize operation.
    struct ComputedFrame: Equatable {
        /// The frame calculated without any padding applied.
        let raw: CGRect

        /// The frame with padding applied (outer bounds padding + inner window padding).
        /// When no padding is configured, this equals `raw`.
        var padded: CGRect

        static let zero = ComputedFrame(raw: .zero, padded: .zero)

        init(raw: CGRect, padded: CGRect) {
            self.raw = raw
            self.padded = padded
        }
    }
}
