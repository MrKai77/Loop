//
//  StashedWindow.swift
//  Loop
//
//  Created by Guillaume Clédat on 28/05/2025.
//

import Foundation

struct StashedWindow {
    let window: Window
    let screenBounds: CGRect
    let direction: StashDirection
}

// MARK: - Frame computation

extension StashedWindow {
    /// Computes the frame for a stashed window.
    ///
    /// - Parameters:
    ///   - peekSize: The number of pixels that remain visible on the screen when the window is stashed.
    ///   - maxPeekPercent: The maximum percentage of the window’s width that can remain visible.
    ///   - padding: User-defined padding. Use `PaddingModel.zero` if padding is disabled.
    /// - Returns: The computed frame for the stashed window.
    func computeStashedFrame(peekSize: CGFloat, maxPeekPercent: CGFloat = 0.2, padding: PaddingModel = .zero) -> CGRect {
        let currentFrame = window.frame
        let minPeekSize: CGFloat = 1
        let maxPeekSize = currentFrame.width * maxPeekPercent
        let clampedPeekSize = max(minPeekSize, min(peekSize, maxPeekSize))

        var stashedFrame = currentFrame

        switch direction {
        case .left:
            stashedFrame.origin.x = screenBounds.minX - currentFrame.width + clampedPeekSize
            // If padding is enabled and not zero, it will be added to screenBounds.
            // We need to remove the padding.left value so the `peekSize` value is respected.
            stashedFrame.origin.x -= padding.left
        case .right:
            stashedFrame.origin.x = screenBounds.maxX - clampedPeekSize
            stashedFrame.origin.x += padding.right
        }

        update(frame: &stashedFrame, in: direction.region, windowPadding: padding.window)

        return stashedFrame
    }

    func computeRevealedFrame(windowPadding: CGFloat = 0) -> CGRect {
        var revealFrame = window.frame

        switch direction {
        case .left:
            revealFrame.origin.x = screenBounds.minX
        case .right:
            revealFrame.origin.x = screenBounds.maxX - revealFrame.width
        }

        update(frame: &revealFrame, in: direction.region, windowPadding: windowPadding)

        return revealFrame
    }

    /// Updates the frame based on the specified region
    ///
    /// Only the y-coordinate and height are modified based on the region.
    /// The x-coordinate should be set based on the `StashDirection` before or after calling this function.
    /// In the future we may add more regions that modify the width as well.
    private func update(frame: inout CGRect, in region: StashRegion, windowPadding: CGFloat = 0) {
        switch region {
        case .top:
            frame.origin.y = screenBounds.minY
        case .center:
            frame.origin.y = screenBounds.midY - frame.height / 2
        case .bottom:
            frame.origin.y = screenBounds.maxY - frame.height
        case .full:
            frame.origin.y = screenBounds.minY
            frame.size.height = screenBounds.height
        case .topHalf:
            frame.origin.y = screenBounds.minY
            frame.size.height = screenBounds.height / 2 - windowPadding / 2
        case .bottomHalf:
            frame.size.height = screenBounds.height / 2 - windowPadding / 2
            frame.origin.y = screenBounds.minY + screenBounds.height / 2 + windowPadding / 2
        }
    }
}
