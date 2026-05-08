//
//  StashedWindowInfo.swift
//  Loop
//
//  Created by Guillaume Clédat on 28/05/2025.
//

import Foundation
import Scribe
import SwiftUI

@Loggable
struct StashedWindowInfo: Equatable {
    let window: Window
    let screen: NSScreen
    let action: WindowAction
    let revealedFrame: CGRect
    let stashedFrame: CGRect

    // MARK: - Frame computation

    static func create(window: Window, screen: NSScreen, action: WindowAction, peekSize: CGFloat) async -> StashedWindowInfo {
        let revealedFrame = await computeRevealedFrame(window: window, screen: screen, action: action)
        let stashedFrame = await computeStashedFrame(window: window, screen: screen, action: action, peekSize: peekSize)

        return StashedWindowInfo(
            window: window,
            screen: screen,
            action: action,
            revealedFrame: revealedFrame,
            stashedFrame: stashedFrame
        )
    }

    func updatingStashedFrame(peekSize: CGFloat) async -> StashedWindowInfo {
        let stashedFrame = await Self.computeStashedFrame(
            window: window,
            screen: screen,
            action: action,
            peekSize: peekSize
        )

        return StashedWindowInfo(
            window: window,
            screen: screen,
            action: action,
            revealedFrame: revealedFrame,
            stashedFrame: stashedFrame
        )
    }

    func updatingFrames(screen: NSScreen, peekSize: CGFloat) async -> StashedWindowInfo {
        await Self.create(
            window: window,
            screen: screen,
            action: action,
            peekSize: peekSize
        )
    }

    /// Computes the frame for a stashed window.
    private static func computeStashedFrame(window: Window, screen: NSScreen, action: WindowAction, peekSize: CGFloat, maxPeekPercent: CGFloat = 0.2) async -> CGRect {
        let bounds = screen.cgSafeScreenFrame
        var frame = await WindowFrameResolver.getFrame(for: action, window: window, bounds: bounds)

        let minPeekSize: CGFloat = 1

        switch action.stashEdge {
        case .left, .right:
            let maxPeekSize = frame.width * maxPeekPercent
            let clampedPeekSize = max(minPeekSize, min(peekSize, maxPeekSize))

            if action.stashEdge == .left {
                frame.origin.x = bounds.minX - frame.width + clampedPeekSize
            } else {
                frame.origin.x = bounds.maxX - clampedPeekSize
            }

        case .bottom:
            let maxPeekSize = frame.height * maxPeekPercent
            let clampedPeekSize = max(minPeekSize, min(peekSize, maxPeekSize))
            frame.origin.y = bounds.maxY - clampedPeekSize

        case .none:
            break
        }

        return frame
    }

    private static func computeRevealedFrame(window: Window, screen: NSScreen, action: WindowAction) async -> CGRect {
        let context = ResizeContext(window: window, screen: screen)
        context.setAction(to: action, parent: nil)
        await context.refreshResolvedState()
        return context.getTargetFrame().padded
    }
}
