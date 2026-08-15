//
//  SnappingEngine.swift
//  Loop
//
//  Created for Loop Fork.
//

import AppKit
import Defaults

enum SnappingEngine {
    /// Snaps a candidate window frame against screen edges, neighboring windows, or grid lines.
    static func snap(
        frame: CGRect,
        on screen: NSScreen,
        ignoreWindowID: CGWindowID? = nil,
        threshold: CGFloat = Defaults[.magneticSnapThreshold]
    ) -> CGRect {
        // If grid snapping is enabled, prioritize grid alignment
        if Defaults[.gridSnappingEnabled] {
            return GridEngine.snapMove(frame: frame, on: screen)
        }

        var snappedFrame = frame
        let screenBounds = screen.cgSafeScreenFrame
        let gap = Defaults[.enablePadding] ? Defaults[.padding].window : 0

        var bestDeltaX: CGFloat?
        var bestDeltaY: CGFloat?

        // MARK: - 1. Screen Edge Snapping
        if Defaults[.magneticEdgeSnapping] {
            // Left edge to screen left
            let dLeftToScreenLeft = screenBounds.minX - frame.minX
            if abs(dLeftToScreenLeft) <= threshold {
                bestDeltaX = dLeftToScreenLeft
            }

            // Right edge to screen right
            let dRightToScreenRight = screenBounds.maxX - frame.maxX
            if abs(dRightToScreenRight) <= threshold {
                if bestDeltaX == nil || abs(dRightToScreenRight) < abs(bestDeltaX!) {
                    bestDeltaX = dRightToScreenRight
                }
            }

            // Top edge to screen top
            let dTopToScreenTop = screenBounds.minY - frame.minY
            if abs(dTopToScreenTop) <= threshold {
                bestDeltaY = dTopToScreenTop
            }

            // Bottom edge to screen bottom
            let dBottomToScreenBottom = screenBounds.maxY - frame.maxY
            if abs(dBottomToScreenBottom) <= threshold {
                if bestDeltaY == nil || abs(dBottomToScreenBottom) < abs(bestDeltaY!) {
                    bestDeltaY = dBottomToScreenBottom
                }
            }
        }

        // MARK: - 2. Window-to-Window Snapping
        if Defaults[.magneticWindowSnapping] {
            let neighborWindows = WindowUtility.windowList().filter { window in
                guard let ignoreID = ignoreWindowID else { return true }
                return window.cgWindowID != ignoreID &&
                    !window.frame.isEmpty &&
                    window.frame.width > 50 &&
                    window.frame.height > 50
            }

            for neighbor in neighborWindows {
                let nFrame = neighbor.frame

                // Check vertical overlap for horizontal snapping
                let verticalOverlap = max(0, min(frame.maxY, nFrame.maxY) - max(frame.minY, nFrame.minY))
                if verticalOverlap > 10 || (frame.minY <= nFrame.maxY + threshold && frame.maxY >= nFrame.minY - threshold) {
                    // Active Left -> Neighbor Right (+ gap)
                    let dLeftToNeighborRight = (nFrame.maxX + gap) - frame.minX
                    if abs(dLeftToNeighborRight) <= threshold {
                        if bestDeltaX == nil || abs(dLeftToNeighborRight) < abs(bestDeltaX!) {
                            bestDeltaX = dLeftToNeighborRight
                        }
                    }

                    // Active Right -> Neighbor Left (- gap)
                    let dRightToNeighborLeft = (nFrame.minX - gap) - frame.maxX
                    if abs(dRightToNeighborLeft) <= threshold {
                        if bestDeltaX == nil || abs(dRightToNeighborLeft) < abs(bestDeltaX!) {
                            bestDeltaX = dRightToNeighborLeft
                        }
                    }

                    // Flush Left alignment
                    let dLeftToNeighborLeft = nFrame.minX - frame.minX
                    if abs(dLeftToNeighborLeft) <= threshold {
                        if bestDeltaX == nil || abs(dLeftToNeighborLeft) < abs(bestDeltaX!) {
                            bestDeltaX = dLeftToNeighborLeft
                        }
                    }

                    // Flush Right alignment
                    let dRightToNeighborRight = nFrame.maxX - frame.maxX
                    if abs(dRightToNeighborRight) <= threshold {
                        if bestDeltaX == nil || abs(dRightToNeighborRight) < abs(bestDeltaX!) {
                            bestDeltaX = dRightToNeighborRight
                        }
                    }
                }

                // Check horizontal overlap for vertical snapping
                let horizontalOverlap = max(0, min(frame.maxX, nFrame.maxX) - max(frame.minX, nFrame.minX))
                if horizontalOverlap > 10 || (frame.minX <= nFrame.maxX + threshold && frame.maxX >= nFrame.minX - threshold) {
                    // Active Top -> Neighbor Bottom (+ gap)
                    let dTopToNeighborBottom = (nFrame.maxY + gap) - frame.minY
                    if abs(dTopToNeighborBottom) <= threshold {
                        if bestDeltaY == nil || abs(dTopToNeighborBottom) < abs(bestDeltaY!) {
                            bestDeltaY = dTopToNeighborBottom
                        }
                    }

                    // Active Bottom -> Neighbor Top (- gap)
                    let dBottomToNeighborTop = (nFrame.minY - gap) - frame.maxY
                    if abs(dBottomToNeighborTop) <= threshold {
                        if bestDeltaY == nil || abs(dBottomToNeighborTop) < abs(bestDeltaY!) {
                            bestDeltaY = dBottomToNeighborTop
                        }
                    }

                    // Flush Top alignment
                    let dTopToNeighborTop = nFrame.minY - frame.minY
                    if abs(dTopToNeighborTop) <= threshold {
                        if bestDeltaY == nil || abs(dTopToNeighborTop) < abs(bestDeltaY!) {
                            bestDeltaY = dTopToNeighborTop
                        }
                    }

                    // Flush Bottom alignment
                    let dBottomToNeighborBottom = nFrame.maxY - frame.maxY
                    if abs(dBottomToNeighborBottom) <= threshold {
                        if bestDeltaY == nil || abs(dBottomToNeighborBottom) < abs(bestDeltaY!) {
                            bestDeltaY = dBottomToNeighborBottom
                        }
                    }
                }
            }
        }

        if let dx = bestDeltaX {
            snappedFrame.origin.x += dx
        }
        if let dy = bestDeltaY {
            snappedFrame.origin.y += dy
        }

        return snappedFrame
    }

    /// Snaps a resized window frame according to its anchor point.
    static func snapResize(
        frame: CGRect,
        anchor: AltDragAnchor,
        on screen: NSScreen,
        ignoreWindowID: CGWindowID? = nil,
        threshold: CGFloat = Defaults[.magneticSnapThreshold]
    ) -> CGRect {
        if Defaults[.gridSnappingEnabled] {
            return GridEngine.snapResize(frame: frame, on: screen)
        }

        var snapped = snap(frame: frame, on: screen, ignoreWindowID: ignoreWindowID, threshold: threshold)

        // Ensure minimum window size
        snapped.size.width = max(150, snapped.size.width)
        snapped.size.height = max(100, snapped.size.height)

        return snapped
    }
}
