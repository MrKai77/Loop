//
//  StashedWindowInfo.swift
//  Loop
//
//  Created by Guillaume Clédat on 28/05/2025.
//

import Foundation
import Scribe
import SwiftUI

struct StashedWindowInfo: Equatable {
    let window: Window
    let screen: NSScreen
    let action: WindowAction

    // MARK: - Frame computation

    /// Computes the frame for a stashed window.
    func computeStashedFrame(peekSize: CGFloat, maxPeekPercent: CGFloat = 0.2) -> CGRect {
        let bounds = screen.safeScreenFrame
        var frame = action.getFrame(window: window, bounds: bounds, screen: screen)

        let minPeekSize: CGFloat = 1
        let maxPeekSize = frame.width * maxPeekPercent
        let clampedPeekSize = max(minPeekSize, min(peekSize, maxPeekSize))

        switch action.stashEdge {
        case .left:
            frame.origin.x = bounds.minX - frame.width + clampedPeekSize
        case .right:
            frame.origin.x = bounds.maxX - clampedPeekSize
        case .none:
            Log.warn("Trying to compute the stash frame for a non-stash related action.", category: .stashedWindow)
        }

        return frame
    }

    func computeRevealedFrame() -> CGRect {
        action.getFrame(window: window, bounds: screen.safeScreenFrame, screen: screen)
    }
}
