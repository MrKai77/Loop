//
//  ScreenUtility.swift
//  Loop
//
//  Created by Kai Azim on 2024-01-11.
//

import Defaults
import SwiftUI

enum ScreenCycleOrder: String, Defaults.Serializable, CaseIterable, Identifiable {
    var id: Self { self }

    case zPattern
    case clockwise

    var name: LocalizedStringKey {
        switch self {
        case .zPattern:
            "Z-pattern"
        case .clockwise:
            "Clockwise"
        }
    }
    
    var image: Image {
        switch self {
        case .zPattern:
            Image(.arrowTriangleheadSwapRotated)
        case .clockwise:
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
        }
    }
}

enum ScreenUtility {
    private static var navigationUtility = DirectionalNavigationUtility<NSScreen>(
        minDirectionalSpan: .points(1),
        minStackedArea: .percentage(100), // Won't be used since screens cannot be stacked
        frameProvider: \.frame
    )

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
        switch Defaults[.screenCycleOrder] {
        case .zPattern:
            getOrderedScreensZPattern()
        case .clockwise:
            getOrderedScreensClockwise()
        }
    }

    /// Z-pattern: left-to-right within each row, top row first.
    private static func getOrderedScreensZPattern() -> [NSScreen] {
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

    /// Walk tracing outer perimeter first, then inner layers.
    ///
    /// The walk prefers to continue straight, then turn clockwise. This ensures the
    /// outer perimeter is fully traced before the walk turns inward.
    private static func getOrderedScreensClockwise() -> [NSScreen] {
        var unvisited = Set(NSScreen.screens)
        var ordered: [NSScreen] = []

        while !unvisited.isEmpty {
            // Pick starting screen: topmost, then leftmost
            guard let start = unvisited.max(by: { s1, s2 in
                if abs(s1.frame.maxY - s2.frame.maxY) > 1 {
                    return s1.frame.maxY < s2.frame.maxY
                }
                return s1.frame.minX > s2.frame.minX
            }) else { break }

            var current = start
            unvisited.remove(current)
            ordered.append(current)

            var lastDirection: NavigationDirection?
            while let (next, direction) = nearestUnvisitedScreen(
                from: current,
                lastDirection: lastDirection,
                in: unvisited
            ) {
                unvisited.remove(next)
                ordered.append(next)
                current = next
                lastDirection = direction
            }
        }

        return ordered
    }

    /// Tries to find the nearest unvisited screen using momentum-based clockwise priority.
    /// The direction priority favors continuing straight, then turning clockwise.
    /// This produces a spiral rather than a snake pattern on large grids.
    private static func nearestUnvisitedScreen(
        from current: NSScreen,
        lastDirection: NavigationDirection?,
        in unvisited: Set<NSScreen>
    ) -> (NSScreen, NavigationDirection)? {
        let directions = clockwisePriority(after: lastDirection)
        let others = Array(unvisited)

        for direction in directions {
            if let neighbor = navigationUtility.directionalItem(
                from: current,
                others: others,
                direction: direction,
                canWrap: false
            ) {
                return (neighbor, direction)
            }
        }

        return nil
    }

    /// Returns the direction search order for clockwise traversal with momentum.
    private static func clockwisePriority(after lastDirection: NavigationDirection?) -> [NavigationDirection] {
        guard let last = lastDirection else {
            return [.right, .top, .left, .bottom]
        }

        // For each direction: [straight, clockwise turn, counter-clockwise turn, reverse]
        switch last {
        case .right:  return [.right, .top, .left, .bottom]
        case .top:    return [.top, .left, .bottom, .right]
        case .left:   return [.left, .bottom, .right, .top]
        case .bottom: return [.bottom, .right, .top, .left]
        }
    }

    // MARK: Directional Screens

    /// Finds a screen to a set edge from the screen of reference.
    /// - Parameters:
    ///   - currentScreen: the screen of reference, i.e. the current screen.
    ///   - direction: the direction of the screen we want to find.
    ///   - canRestartCycle: whether this should continuously loop through all screens, rather than returning `nil` at the end.
    /// - Returns: the screen at the respective edge, or the first screen in the row/column if `canRestartCycle` is enabled. Otherwise, it will return `nil`.
    static func directionalScreen(
        from currentScreen: NSScreen,
        direction: NavigationDirection,
        canWrap: Bool = true
    ) -> NSScreen? {
        let currentDisplayID = currentScreen.displayID
        let otherScreens = NSScreen.screens.filter { $0.displayID != currentDisplayID }

        return navigationUtility.directionalItem(
            from: currentScreen,
            others: otherScreens,
            direction: direction,
            canWrap: canWrap
        )
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
