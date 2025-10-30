//
//  ScreenUtility.swift
//  Loop
//
//  Created by Kai Azim on 2024-01-11.
//

import SwiftUI

enum ScreenUtility {
    private static let overlapThreshold: CGFloat = 10.0

    /// Returns a screen containing a window, if found.
    /// - Parameter window: the window whose screen we want to find.
    /// - Returns: the screen containing the window.
    static func screenContaining(_ window: Window) -> NSScreen? {
        let screens = NSScreen.screens

        if screens.count == 1, let firstScreen = screens.first {
            return firstScreen
        }

        guard let currentScreen = findScreen(with: window, screens) else {
            return screens.first
        }

        return currentScreen
    }

    /// Finds a screen contianing a window, within an array of screens.
    /// - Parameters:
    ///   - window: the window whose screen we want to find.
    ///   - screens: an array of screens to search within
    /// - Returns: the screen containing the window.
    private static func findScreen(with window: Window, _ screens: [NSScreen]) -> NSScreen? {
        var result: NSScreen?

        let windowFrame = window.frame
        var largestRecordedArea: CGFloat = .zero

        for screen in screens {
            let screenFrame = screen.displayBounds

            if screenFrame.contains(windowFrame) {
                result = screen
                break
            }

            let intersectSize = screenFrame.intersection(windowFrame).size
            let intersectArea = intersectSize.area

            if intersectArea > largestRecordedArea {
                largestRecordedArea = intersectArea
                result = screen
            }
        }

        return result
    }

    // MARK: Next/Previous Screen

    /// Determines the next screen from a screen of reference.
    /// - Parameters:
    ///   - screen: the current screen
    ///   - canRestartCycle: whether this should continuously loop through all screens, rather than stopping at the end.
    /// - Returns: the next screen, or the first screen in the cycle if `canRestartCycle` is enabled. Otherwise, it will return `nil`.
    static func nextScreen(from screen: NSScreen, canRestartCycle: Bool = true) -> NSScreen? {
        let screens = getOrderedScreens()

        if let nextScreen = screens.next(from: screen) {
            return nextScreen
        }
        return canRestartCycle ? screens.first : nil
    }

    /// Determines the previous screen from a screen of reference.
    /// - Parameters:
    ///   - screen: the current screen
    ///   - canRestartCycle: whether this should continuously loop through all screens, rather than stopping at the end.
    /// - Returns: the previous screen, or the last screen in the cycle if `canRestartCycle` is enabled. Otherwise, it will return `nil`.
    static func previousScreen(from screen: NSScreen, canRestartCycle: Bool = true) -> NSScreen? {
        let screens = getOrderedScreens()

        if let previousScreen = screens.previous(from: screen) {
            return previousScreen
        }
        return canRestartCycle ? screens.last : nil
    }

    /// Sorts all NSScreens in an order such that the next/previous screen are in positional order.
    private static func getOrderedScreens() -> [NSScreen] {
        NSScreen.screens.sorted { screen1, screen2 in
            if screen2.frame.maxY <= screen1.frame.minY {
                return true
            }

            if screen1.frame.maxY <= screen2.frame.minY {
                return false
            }

            return screen1.frame.minX < screen2.frame.minX
        }
    }

    // MARK: Directional Screens

    /// Finds a screen to a set edge from the screen of reference.
    /// - Parameters:
    ///   - screen: the screen of reference, i.e. the current screen.
    ///   - edge: the direction of the screen we want to find.
    ///   - canRestartCycle: whether this should continuously loop through all screens, rather than returning `nil` at the end.
    /// - Returns: the screen at the respective edge, or the first screen in the row/column if `canRestartCycle` is enabled. Otherwise, it will return `nil`.
    static func directionalScreen(from screen: NSScreen, edge: Edge, canRestartCycle: Bool = true) -> NSScreen? {
        let screens = NSScreen.screens

        if let neighbor = directDirectionalScreen(from: screen, in: screens, edge: edge) {
            return neighbor
        }

        guard canRestartCycle else { return nil }

        let overlaps = overlappingScreens(from: screen, in: screens, edge: edge)

        switch edge {
        case .leading:
            return overlaps.max(by: { $0.frame.maxX < $1.frame.maxX }) ?? screens.max { $0.frame.maxX < $1.frame.maxX }
        case .trailing:
            return overlaps.min(by: { $0.frame.minX < $1.frame.minX }) ?? screens.min { $0.frame.minX < $1.frame.minX }
        case .top:
            return overlaps.max(by: { $0.frame.maxY < $1.frame.maxY }) ?? screens.max { $0.frame.maxY < $1.frame.maxY }
        case .bottom:
            return overlaps.min(by: { $0.frame.minY < $1.frame.minY }) ?? screens.min { $0.frame.minY < $1.frame.minY }
        }
    }

    /// Finds a screen to a set edge from the screen of reference, without the option to restart the cycle.
    /// - Parameters:
    ///   - screen: the screen of reference, i.e. the current screen.
    ///   - screens: an array of screens to search through.
    ///   - edge: the edge of which the returned screen should be.
    /// - Returns: the screen at the respective edge, or if not found, `nil`.
    private static func directDirectionalScreen(
        from screen: NSScreen,
        in screens: [NSScreen],
        edge: Edge
    ) -> NSScreen? {
        screens
            .filter { other in
                guard other != screen else { return false }
                return overlapBetweenScreens(for: edge, current: screen, other: other) >= overlapThreshold
                    && isNeighboringScreen(edge: edge, current: screen, other: other)
            }
            .min {
                distanceBetweenScreens(for: edge, current: screen, other: $0) < distanceBetweenScreens(for: edge, current: screen, other: $1)
            }
    }

    /// Finds an array of overlapping screens in a specific axis.
    /// - Parameters:
    ///   - screen: the screen of reference, i.e. the current screen.
    ///   - screens: an array of screens to search through.
    ///   - edge: the edge of the current screen, of which we are trying to find overlapping screens of, in the same axis.
    /// - Returns: an array of screens that either vertically or horizontally overlap with the current screen.
    private static func overlappingScreens(
        from screen: NSScreen,
        in screens: [NSScreen],
        edge: Edge
    ) -> [NSScreen] {
        let currentFrame = screen.frame
        return screens.filter { other in
            guard other != screen else { return false }
            let overlap: CGFloat = switch edge {
            case .leading, .trailing: // Vertical overlap
                min(currentFrame.maxY, other.frame.maxY) - max(currentFrame.minY, other.frame.minY)
            case .top, .bottom: // Horizontal overlap
                min(currentFrame.maxX, other.frame.maxX) - max(currentFrame.minX, other.frame.minX)
            }
            return overlap >= overlapThreshold
        }
    }

    /// Determines the overlap between two screens, either in a vertical or horizonal axis.
    /// - Parameters:
    ///   - edge: the edge of which the other screen should be at.
    ///   - current: the screen of reference, i.e. the current screen.
    ///   - other: the screen to compare against.
    /// - Returns: the amount of points (pt) of horizontal/vertical overlap between the two inputted screens.
    private static func overlapBetweenScreens(for edge: Edge, current: NSScreen, other: NSScreen) -> CGFloat {
        switch edge {
        case .leading, .trailing: // Vertical overlap
            min(current.frame.maxY, other.frame.maxY) - max(current.frame.minY, other.frame.minY)
        case .top, .bottom: // Horizontal overlap
            min(current.frame.maxX, other.frame.maxX) - max(current.frame.minX, other.frame.minX)
        }
    }

    /// Determines if the inputted screen is a candidate to be beside the current screen.
    /// - Parameters:
    ///   - edge: the edge of which the other screen may be positioned at.
    ///   - current: the screen of reference, i.e. the current screen.
    ///   - other: the screen to compare against, to see if it is a neighbor
    /// - Returns: whether this screen is indeed a neighboring screen.
    private static func isNeighboringScreen(edge: Edge, current: NSScreen, other: NSScreen) -> Bool {
        switch edge {
        case .leading:
            other.frame.maxX <= current.frame.minX + overlapThreshold
        case .trailing:
            other.frame.minX >= current.frame.maxX - overlapThreshold
        case .top:
            other.frame.minY >= current.frame.maxY - overlapThreshold
        case .bottom:
            other.frame.maxY <= current.frame.minY + overlapThreshold
        }
    }

    /// Determines the distance between two screens.
    /// - Parameters:
    ///   - edge: the edge of which we are trying to find the distance from.
    ///   - current: the screen of reference, i.e. the current screen. The edge will be considered from this screen.
    ///   - other: the screen to compare and measure against.
    /// - Returns: the distance between these two screens, from the respective edge.
    private static func distanceBetweenScreens(for edge: Edge, current: NSScreen, other: NSScreen) -> CGFloat {
        switch edge {
        case .leading:
            current.frame.minX - other.frame.maxX
        case .trailing:
            other.frame.minX - current.frame.maxX
        case .top:
            other.frame.minY - current.frame.maxY
        case .bottom:
            current.frame.minY - other.frame.maxY
        }
    }
}

// MARK: - Generic Directional Navigation

extension ScreenUtility {
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

private extension Array where Element: Hashable {
    func next(from item: Element) -> Element? {
        guard let index = firstIndex(of: item) else {
            return nil
        }

        if index + 1 < count {
            return self[index + 1]
        }

        return nil
    }

    func previous(from item: Element) -> Element? {
        guard let index = firstIndex(of: item) else {
            return nil
        }

        if index - 1 >= 0 {
            return self[index - 1]
        }

        return nil
    }
}
