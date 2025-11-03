//
//  DirectionalNavigationUtility.swift
//  Loop
//
//  Created by cipher-shad0w on 2025-11-02.
//

import SwiftUI

/// A utility for generic directional navigation between items with frames.
/// This utility provides reusable logic for navigating between items (windows, screens, etc.)
/// in a specific direction based on their geometric frames.
final class DirectionalNavigationUtility<T> {
    let minimumSharedSpan: SharedSpan
    let frameProvider: (T) -> CGRect

    enum SharedSpan {
        case percentage(CGFloat)
        case pixels(CGFloat)
    }

    /// Initializes a new instance of `DirectionalNavigationUtility`.
    /// - Parameters:
    ///   - minimumSharedSpan: The minimum amount of axis span that two items must share for the candidate to be considered aligned with the current item.
    ///   - frameProvider: Closure mapping an item to its CGRect frame.
    init(minimumSharedSpan: SharedSpan, frameProvider: @escaping (T) -> CGRect) {
        self.minimumSharedSpan = minimumSharedSpan
        self.frameProvider = frameProvider
    }

    /// Generic directional navigation for any items with a frame (e.g., Windows or Screens)
    /// - Parameters:
    ///   - current: The current item
    ///   - items: All available items to search through
    ///   - edge: The direction to search
    ///   - canRestartCycle: Whether to wrap around when no items found in direction
    ///   - frameProvider: Closure that extracts the CGRect frame from an item
    /// - Returns: The next item in the specified direction, or nil
    func directionalItem(
        from current: T,
        in items: [T],
        edge: Edge,
        canWrap: Bool = true
    ) -> T? {
        let currentFrame = frameProvider(current)
        let axis: Axis = (edge == .leading || edge == .trailing) ? .horizontal : .vertical

        let itemsInSpan = filterItemsBySharedSpan(
            in: items,
            axis: axis,
            currentFrame: currentFrame
        )

        // Try to find direct neighbor first
        if let neighbor = directDirectionalItem(
            in: itemsInSpan,
            edge: edge,
            currentFrame: currentFrame
        ) {
            return neighbor
        }

        // If no direct neighbor and wrap-around is disabled, return nil
        guard canWrap else { return nil }

        // Wrap around to the furthest item in the opposite direction
        return furthestItemInDirection(
            in: itemsInSpan.isEmpty ? items : itemsInSpan,
            edge: edge.flipped
        )
    }

    /// Filters items down to those that share enough configured axis span with the current frame to be considered adjacent.
    /// - Parameters:
    ///   - items: List of all candidate items.
    ///   - axis: The axis along which to measure shared span (horizontal or vertical).
    ///   - currentFrame: The frame of the current item.
    /// - Returns: Array of items whose overlap along the relevant axis passes the minimumSharedSpan threshold, or are fully contained within the axis span of the current frame.
    private func filterItemsBySharedSpan(
        in items: [T],
        axis: Axis,
        currentFrame: CGRect
    ) -> [T] {
        items
            .filter { other in
                let otherFrame = frameProvider(other)
                guard otherFrame != currentFrame else { return false }

                let sharedAxisPixelSpan = switch axis {
                case .horizontal:
                    min(currentFrame.maxY, otherFrame.maxY) - max(currentFrame.minY, otherFrame.minY)
                case .vertical:
                    min(currentFrame.maxX, otherFrame.maxX) - max(currentFrame.minX, otherFrame.minX)
                }

                let fullSpanOverlaps = switch axis {
                case .horizontal:
                    sharedAxisPixelSpan == otherFrame.height
                case .vertical:
                    sharedAxisPixelSpan == otherFrame.width
                }

                if fullSpanOverlaps {
                    return true
                }

                let consideredAxisPixelLength: CGFloat = axis == .horizontal ? currentFrame.height : currentFrame.width

                switch minimumSharedSpan {
                case let .percentage(minPercentage):
                    let sharedSpanPercent = consideredAxisPixelLength > 0 ? max(0, sharedAxisPixelSpan / consideredAxisPixelLength) : 0
                    return sharedSpanPercent > minPercentage
                case let .pixels(minPixels):
                    return sharedAxisPixelSpan > minPixels
                }
            }
    }

    /// Returns item that is the closest neighbor in a given direction
    /// - Parameters:
    ///   - items: Candidates filtered to be axis-aligned with the current window.
    ///   - edge: Direction to search for the neighbor.
    ///   - currentFrame: The frame of the current item.
    /// - Returns: The item whose center is nearest and lies strictly in the given direction, or nil if none are eligible.
    private func directDirectionalItem(
        in items: [T],
        edge: Edge,
        currentFrame: CGRect
    ) -> T? {
        items
            .filter { other in
                let otherFrame = frameProvider(other)
                guard otherFrame != currentFrame else { return false }

                // Directional check: consider center as well
                let currentCenter = currentFrame.center
                let otherCenter = otherFrame.center
                let isInDirection: Bool = switch edge {
                case .leading: otherCenter.x < currentCenter.x
                case .trailing: otherCenter.x > currentCenter.x
                case .top: otherCenter.y < currentCenter.y
                case .bottom: otherCenter.y > currentCenter.y
                }

                // Use a lower overlap threshold for big windows, or a percent threshold
                return isInDirection
            }
            .min {
                let currentCenter = currentFrame.center
                let aCenter = frameProvider($0).center
                let bCenter = frameProvider($1).center

                let distA = currentCenter.distance(to: aCenter)
                let distB = currentCenter.distance(to: bCenter)
                return distA < distB
            }
    }

    /// Selects the furthest item in the provided direction, useful for wrapping.
    /// - Parameters:
    ///   - items: List of candidate items.
    ///   - edge: Direction in which we want the furthest item.
    /// - Returns: The item with the greatest extent in the specified direction, or nil if none are available.
    private func furthestItemInDirection(
        in items: [T],
        edge: Edge
    ) -> T? {
        switch edge {
        case .leading:
            items.min(by: { frameProvider($0).minX < frameProvider($1).minX })
        case .trailing:
            items.max(by: { frameProvider($0).maxX < frameProvider($1).maxX })
        case .top:
            items.min(by: { frameProvider($0).minY < frameProvider($1).minY })
        case .bottom:
            items.max(by: { frameProvider($0).maxY < frameProvider($1).maxY })
        }
    }
}

private extension Edge {
    /// Returns the opposite direction of the current Edge.
    var flipped: Edge {
        switch self {
        case .top:
            .bottom
        case .leading:
            .trailing
        case .bottom:
            .top
        case .trailing:
            .leading
        }
    }
}
