//
//  DirectionalNavigationUtility.swift
//  Loop
//
//  Created by cipher-shad0w on 2025-11-02.
//

import SwiftUI

enum NavigationDirection {
    case top
    case bottom
    case right
    case left

    var flipped: NavigationDirection {
        switch self {
        case .top: .bottom
        case .bottom: .top
        case .right: .left
        case .left: .right
        }
    }

    var axis: Axis {
        switch self {
        case .left, .right: .horizontal
        default: .vertical
        }
    }
}

/// A utility for generic directional navigation between items with frames.
/// This utility provides reusable logic for navigating between items (windows, screens, etc.)
/// in a specific direction based on their geometric frames.
final class DirectionalNavigationUtility<T> {
    let minDirectionalSpan: SharedUnit
    let minStackedArea: SharedUnit
    let frameProvider: (T) -> CGRect

    enum SharedUnit {
        case percentage(CGFloat)
        case points(CGFloat)
    }

    /// Initializes a new instance of `DirectionalNavigationUtility`.
    /// - Parameters:
    ///   - minDirectionalSpan: The minimum amount of axis span that two items must share for the candidate to be considered aligned with the current item.
    ///   - minStackedArea: The minimum area two items must share to be considered stacked.
    ///   - frameProvider: Closure mapping an item to its CGRect frame.
    init(
        minDirectionalSpan: SharedUnit,
        minStackedArea: SharedUnit,
        frameProvider: @escaping (T) -> CGRect
    ) {
        self.minDirectionalSpan = minDirectionalSpan
        self.minStackedArea = minStackedArea
        self.frameProvider = frameProvider
    }

    /// Generic directional navigation for any items with a frame (e.g., Windows or Screens)
    /// - Parameters:
    ///   - current: The current item
    ///   - items: All available items to search through
    ///   - direction: The direction to search
    ///   - canRestartCycle: Whether to wrap around when no items found in direction
    ///   - frameProvider:  Closure that extracts the CGRect frame from an item
    /// - Returns: The next item in the specified direction, or nil
    func directionalItem(
        from current: T,
        in items: [T],
        direction: NavigationDirection,
        canWrap: Bool = true
    ) -> T? {
        let currentFrame = frameProvider(current)

        let itemsInSpan = filterItemsBySharedSpan(
            in: items,
            axis: direction.axis,
            currentFrame: currentFrame
        )

        // Try to find direct neighbor first
        if let neighbor = directDirectionalItem(
            in: itemsInSpan,
            direction: direction,
            currentFrame: currentFrame
        ) {
            return neighbor
        }

        // If no direct neighbor and wrap-around is disabled, return nil
        guard canWrap else { return nil }

        // Wrap around to the furthest item in the opposite direction
        return furthestItemInDirection(
            in: itemsInSpan.isEmpty ? items : itemsInSpan,
            direction: direction.flipped
        )
    }

    /// Cycles through items in a stack order based on their position in the array.
    /// Only considers items that meet the minStackedArea threshold with the current item.
    /// - Parameters:
    ///   - current: The current item
    ///   - items: All available items in stack order
    /// - Returns: The next item in the stack cycle, or nil if not found or wrapping is disabled
    func cycleInStack(
        from current: T,
        in items: [T]
    ) -> T? {
        guard !items.isEmpty else { return nil }

        let currentFrame = frameProvider(current)

        let overlappingItems = filterItemsBySharedArea(
            in: items,
            currentFrame: currentFrame
        )

        return overlappingItems.last
    }

    /// Filters items down to those that share enough configured axis span with the current frame to be considered adjacent.
    /// - Parameters:
    ///   - items: List of all candidate items.
    ///   - axis: The axis along which to measure shared span (horizontal or vertical).
    ///   - currentFrame: The frame of the current item.
    /// - Returns: Array of items whose overlap along the relevant axis passes the minDirectionalSpan threshold, or are fully contained within the axis span of the current frame.
    private func filterItemsBySharedSpan(
        in items: [T],
        axis: Axis,
        currentFrame: CGRect
    ) -> [T] {
        items
            .filter { other in
                let otherFrame = frameProvider(other)
                guard otherFrame != currentFrame else { return false }

                let sharedAxisPointSpan = switch axis {
                case .horizontal:
                    min(currentFrame.maxY, otherFrame.maxY) - max(currentFrame.minY, otherFrame.minY)
                case .vertical:
                    min(currentFrame.maxX, otherFrame.maxX) - max(currentFrame.minX, otherFrame.minX)
                }

                let fullSpanOverlaps = switch axis {
                case .horizontal:
                    sharedAxisPointSpan == otherFrame.height
                case .vertical:
                    sharedAxisPointSpan == otherFrame.width
                }

                if fullSpanOverlaps {
                    return true
                }

                let consideredAxisPointLength: CGFloat = axis == .horizontal ? currentFrame.height : currentFrame.width

                switch minDirectionalSpan {
                case let .percentage(minPercentage):
                    let sharedSpanPercent = consideredAxisPointLength > 0 ? max(0, sharedAxisPointSpan / consideredAxisPointLength) : 0
                    return (sharedSpanPercent * 100) > minPercentage
                case let .points(minPoints):
                    return sharedAxisPointSpan > minPoints
                }
            }
    }

    /// Filters items down to those that share enough configured area with the current frame to be considered stacked.
    /// - Parameters:
    ///   - items: List of all candidate items.
    ///   - currentFrame: The frame of the current item.
    /// - Returns: Array of items whose overlapping area passes the minStackedArea threshold, measured as either a percentage of either frame's total area or as absolute points.
    private func filterItemsBySharedArea(
        in items: [T],
        currentFrame: CGRect
    ) -> [T] {
        let currentArea = currentFrame.size.area

        return items
            .filter { other in
                let otherFrame = frameProvider(other)
                guard otherFrame != currentFrame else { return false }

                let intersect = otherFrame.intersection(currentFrame)
                let sharedArea = intersect.size.area
                let otherArea = otherFrame.size.area

                switch minStackedArea {
                case let .percentage(minPercentage):
                    let overlaps1 = 100 * (sharedArea / currentArea) > minPercentage
                    let overlaps2 = 100 * (sharedArea / otherArea) > minPercentage

                    return overlaps1 || overlaps2
                case let .points(minPoints):
                    return sharedArea > minPoints
                }
            }
    }

    /// Returns item that is the closest neighbor in a given direction
    /// - Parameters:
    ///   - items: Candidates filtered to be axis-aligned with the current window.
    ///   - direction: Direction to search for the neighbor.
    ///   - currentFrame: The frame of the current item.
    /// - Returns: The item whose center is nearest and lies strictly in the given direction, or nil if none are eligible.
    private func directDirectionalItem(
        in items: [T],
        direction: NavigationDirection,
        currentFrame: CGRect
    ) -> T? {
        items
            .filter { other in
                let otherFrame = frameProvider(other)
                guard otherFrame != currentFrame else { return false }

                // Directional check: consider center as well
                let currentCenter = currentFrame.center
                let otherCenter = otherFrame.center
                let isInDirection: Bool = switch direction {
                case .left: otherCenter.x < currentCenter.x
                case .right: otherCenter.x > currentCenter.x
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
    ///   - direction: Direction in which we want the furthest item.
    /// - Returns: The item with the greatest extent in the specified direction, or nil if none are available.
    private func furthestItemInDirection(
        in items: [T],
        direction: NavigationDirection
    ) -> T? {
        switch direction {
        case .left:
            items.min(by: { frameProvider($0).minX < frameProvider($1).minX })
        case .right:
            items.max(by: { frameProvider($0).maxX < frameProvider($1).maxX })
        case .top:
            items.min(by: { frameProvider($0).minY < frameProvider($1).minY })
        case .bottom:
            items.max(by: { frameProvider($0).maxY < frameProvider($1).maxY })
        }
    }
}
