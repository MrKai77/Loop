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
enum DirectionalNavigationUtility {
    private static let overlapThreshold: CGFloat = 10.0

    /// Generic directional navigation for any items with a frame (e.g., Windows or Screens)
    /// - Parameters:
    ///   - current: The current item
    ///   - items: All available items to search through
    ///   - edge: The direction to search
    ///   - canRestartCycle: Whether to wrap around when no items found in direction
    ///   - frameProvider: Closure that extracts the CGRect frame from an item
    /// - Returns: The next item in the specified direction, or nil
    static func directionalItem<T>(
        from current: T,
        in items: [T],
        edge: Edge,
        canRestartCycle: Bool = true,
        frameProvider: (T) -> CGRect
    ) -> T? where T: Equatable {
        let currentFrame = frameProvider(current)

        // Try to find direct neighbor first
        if let neighbor = directDirectionalItem(
            from: current,
            in: items,
            edge: edge,
            currentFrame: currentFrame,
            frameProvider: frameProvider
        ) {
            return neighbor
        }

        // If no direct neighbor and wrap-around is disabled, return nil
        guard canRestartCycle else { return nil }

        // Find overlapping items in the same axis
        let overlaps = overlappingItems(
            from: current,
            in: items,
            edge: edge,
            currentFrame: currentFrame,
            frameProvider: frameProvider
        )

        // Wrap around to the furthest item in the opposite direction
        switch edge {
        case .leading:
            return overlaps.max(by: { frameProvider($0).maxX < frameProvider($1).maxX })
                ?? items.max { frameProvider($0).maxX < frameProvider($1).maxX }
        case .trailing:
            return overlaps.min(by: { frameProvider($0).minX < frameProvider($1).minX })
                ?? items.min { frameProvider($0).minX < frameProvider($1).minX }
        case .top:
            return overlaps.max(by: { frameProvider($0).maxY < frameProvider($1).maxY })
                ?? items.max { frameProvider($0).maxY < frameProvider($1).maxY }
        case .bottom:
            return overlaps.min(by: { frameProvider($0).minY < frameProvider($1).minY })
                ?? items.min { frameProvider($0).minY < frameProvider($1).minY }
        }
    }

    // Find direct neighbor in specified direction
    private static func directDirectionalItem<T>(
        from _: T,
        in items: [T],
        edge: Edge,
        currentFrame: CGRect,
        frameProvider: (T) -> CGRect
    ) -> T? where T: Equatable {
        items
            .filter { other in
                guard frameProvider(other) != currentFrame else { return false }
                let otherFrame = frameProvider(other)
                return overlapBetweenFrames(for: edge, current: currentFrame, other: otherFrame) >= overlapThreshold
                    && isNeighboringFrame(edge: edge, current: currentFrame, other: otherFrame)
            }
            .min {
                distanceBetweenFrames(for: edge, current: currentFrame, other: frameProvider($0)) <
                    distanceBetweenFrames(for: edge, current: currentFrame, other: frameProvider($1))
            }
    }

    // Find overlapping items in the same axis
    private static func overlappingItems<T>(
        from _: T,
        in items: [T],
        edge: Edge,
        currentFrame: CGRect,
        frameProvider: (T) -> CGRect
    ) -> [T] where T: Equatable {
        items.filter { other in
            guard frameProvider(other) != currentFrame else { return false }
            let overlap = overlapBetweenFrames(
                for: edge,
                current: currentFrame,
                other: frameProvider(other)
            )
            return overlap >= overlapThreshold
        }
    }

    // Calculate overlap between two frames
    private static func overlapBetweenFrames(for edge: Edge, current: CGRect, other: CGRect) -> CGFloat {
        switch edge {
        case .leading, .trailing:
            min(current.maxY, other.maxY) - max(current.minY, other.minY)
        case .top, .bottom:
            min(current.maxX, other.maxX) - max(current.minX, other.minX)
        }
    }

    // Check if frame is a neighbor in the specified direction
    private static func isNeighboringFrame(edge: Edge, current: CGRect, other: CGRect) -> Bool {
        switch edge {
        case .leading:
            other.maxX <= current.minX + overlapThreshold
        case .trailing:
            other.minX >= current.maxX - overlapThreshold
        case .top:
            other.minY >= current.maxY - overlapThreshold
        case .bottom:
            other.maxY <= current.minY + overlapThreshold
        }
    }

    // Calculate distance between two frames
    private static func distanceBetweenFrames(for edge: Edge, current: CGRect, other: CGRect) -> CGFloat {
        switch edge {
        case .leading:
            current.minX - other.maxX
        case .trailing:
            other.minX - current.maxX
        case .top:
            other.minY - current.maxY
        case .bottom:
            current.minY - other.maxY
        }
    }
}
