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
