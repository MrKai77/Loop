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

    // MARK: - Frame computation

    /// Computes the frame for a stashed window.
    func computeStashedFrame(peekSize: CGFloat, maxPeekPercent: CGFloat = 0.2) -> CGRect {
        let bounds = screen.cgSafeScreenFrame
        var frame = WindowFrameResolver.getFrame(for: action, window: window, bounds: bounds)

        let minPeekSize: CGFloat = 1
        let maxPeekSize = frame.width * maxPeekPercent
        let clampedPeekSize = max(minPeekSize, min(peekSize, maxPeekSize))

        switch action.stashEdge {
        case .left:
            frame.origin.x = bounds.minX - frame.width + clampedPeekSize
        case .right:
            frame.origin.x = bounds.maxX - clampedPeekSize
        case .none:
            log.warn("Trying to compute the stash frame for a non-stash related action.")
        }

        return frame
    }

    func computeRevealedFrame() -> CGRect {
        let context = ResizeContext(window: window, screen: screen)
        context.setAction(to: action, parent: nil)
        return context.getTargetFrame().padded
    }
}
