//
//  ScreenUtility.swift
//  Loop
//
//  Created by Kai Azim on 2024-01-11.
//

import SwiftUI

enum ScreenUtility {
    // MARK: - Screen Cache

    private static var cachedScreens: [NSScreen]?
    private static var cacheTimestamp: Date?
    private static var cachedScreenCount: Int = 0
    private static let cacheValidityDuration: TimeInterval = 0.5
    private static let cacheQueue = DispatchQueue(label: "com.loop.screenUtility.cache", attributes: .concurrent)
    private static let overlapThreshold: CGFloat = 10.0

    // MARK: - Cache Setup

    static func setupDisplayChangeNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            invalidateScreenCache()
        }
    }

    // MARK: - Public Methods

    static func screenContaining(_ window: Window) -> NSScreen? {
        let screens = getScreensInOrder()
        return screenContaining(window, in: screens)
    }

    static func nextScreen(from screen: NSScreen, canRestartCycle: Bool = true) -> NSScreen? {
        let screens = getScreensInOrder()
        if let nextScreen = screens.next(from: screen) {
            return nextScreen
        }
        return canRestartCycle ? screens.first : nil
    }

    static func previousScreen(from screen: NSScreen, canRestartCycle: Bool = true) -> NSScreen? {
        let screens = getScreensInOrder()
        if let previousScreen = screens.previous(from: screen) {
            return previousScreen
        }
        return canRestartCycle ? screens.last : nil
    }

    static func leftScreen(from screen: NSScreen, canRestartCycle: Bool = true) -> NSScreen? {
        let screens = getScreensInOrder()

        if let leftScreen = leftScreen(from: screen, in: screens) {
            return leftScreen
        }

        guard canRestartCycle else {
            return nil
        }

        let overlappingScreens = overlappingScreens(from: screen, in: screens)

        if let rightmostOverlapping = overlappingScreens.max(by: { $0.frame.maxX < $1.frame.maxX }) {
            return rightmostOverlapping
        }

        let rightmostScreen = screens.max { $0.frame.maxX < $1.frame.maxX }
        return rightmostScreen
    }

    static func rightScreen(from screen: NSScreen, canRestartCycle: Bool = true) -> NSScreen? {
        let screens = getScreensInOrder()

        if let rightScreen = rightScreen(from: screen, in: screens) {
            return rightScreen
        }

        guard canRestartCycle else {
            return nil
        }

        let overlappingScreens = overlappingScreens(from: screen, in: screens)

        if let leftmostOverlapping = overlappingScreens.min(by: { $0.frame.minX < $1.frame.minX }) {
            return leftmostOverlapping
        }

        let leftmostScreen = screens.min { $0.frame.minX < $1.frame.minX }
        return leftmostScreen
    }

    static func topScreen(from screen: NSScreen, canRestartCycle: Bool = true) -> NSScreen? {
        let screens = getScreensInOrder()

        if let topScreen = topScreen(from: screen, in: screens) {
            return topScreen
        }

        guard canRestartCycle else {
            return nil
        }

        let overlappingScreens = overlappingScreens(from: screen, in: screens, verticalOverlap: true)

        if let bottommostOverlapping = overlappingScreens.max(by: { $0.frame.maxY < $1.frame.maxY }) {
            return bottommostOverlapping
        }

        let bottommostScreen = screens.max { $0.frame.maxY < $1.frame.maxY }
        return bottommostScreen
    }

    static func bottomScreen(from screen: NSScreen, canRestartCycle: Bool = true) -> NSScreen? {
        let screens = getScreensInOrder()

        if let bottomScreen = bottomScreen(from: screen, in: screens) {
            return bottomScreen
        }

        guard canRestartCycle else {
            return nil
        }

        let overlappingScreens = overlappingScreens(from: screen, in: screens, verticalOverlap: true)

        if let topmostOverlapping = overlappingScreens.min(by: { $0.frame.minY < $1.frame.minY }) {
            return topmostOverlapping
        }

        let topmostScreen = screens.min { $0.frame.minY < $1.frame.minY }
        return topmostScreen
    }

    // MARK: Private

    private static func invalidateScreenCache() {
        cacheQueue.sync(flags: .barrier) {
            cachedScreens = nil
            cacheTimestamp = nil
            cachedScreenCount = 0
        }
    }

    private static func overlappingScreens(from screen: NSScreen, in screens: [NSScreen], verticalOverlap: Bool = false) -> [NSScreen] {
        let currentFrame = screen.frame

        return screens.filter { otherScreen in
            guard otherScreen != screen else { return false }

            let overlap: CGFloat = if verticalOverlap {
                // For top/bottom navigation, check horizontal overlap
                Swift.min(currentFrame.maxX, otherScreen.frame.maxX) -
                    Swift.max(currentFrame.minX, otherScreen.frame.minX)
            } else {
                // For left/right navigation, check vertical overlap
                Swift.min(currentFrame.maxY, otherScreen.frame.maxY) -
                    Swift.max(currentFrame.minY, otherScreen.frame.minY)
            }

            return overlap >= overlapThreshold
        }
    }

    private static func screenContaining(_ window: Window, in screens: [NSScreen]) -> NSScreen? {
        guard let firstScreen = screens.first else {
            return nil
        }

        if screens.count == 1 {
            return firstScreen
        }

        guard let currentScreen = findScreen(with: window, screens) else {
            return firstScreen
        }

        return currentScreen
    }

    private static func getScreensInOrder() -> [NSScreen] {
        cacheQueue.sync {
            let currentScreenCount = NSScreen.screens.count

            if currentScreenCount != cachedScreenCount {
                cachedScreens = nil
                cacheTimestamp = nil
                cachedScreenCount = currentScreenCount
            }

            if let cached = cachedScreens,
               let timestamp = cacheTimestamp,
               Date().timeIntervalSince(timestamp) < cacheValidityDuration,
               currentScreenCount == cachedScreenCount {
                return cached
            }

            let screens = NSScreen.screens
                .sorted { screen1, screen2 in
                    if abs(screen1.frame.origin.x - screen2.frame.origin.x) > 1.0 {
                        return screen1.frame.origin.x < screen2.frame.origin.x
                    }
                    return screen1.frame.origin.y < screen2.frame.origin.y
                }

            cachedScreens = screens
            cacheTimestamp = Date()
            cachedScreenCount = currentScreenCount

            return screens
        }
    }

    private static func findScreen(with window: Window, _ screens: [NSScreen]) -> NSScreen? {
        var result: NSScreen?

        let windowFrame = window.frame
        var largestRecordedArea: CGFloat = .zero

        for screen in screens {
            let screenFrame = screen.frame

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

    private static func directionalScreen(
        from screen: NSScreen,
        in screens: [NSScreen],
        isCandidate: (NSScreen, NSScreen, CGFloat) -> Bool,
        overlap: (NSScreen, NSScreen) -> CGFloat,
        distance: (NSScreen, NSScreen) -> CGFloat
    ) -> NSScreen? {
        let overlapThreshold: CGFloat = 10.0

        let candidates = screens
            .filter { otherScreen in
                guard otherScreen != screen else { return false }
                let ov = overlap(screen, otherScreen)
                return isCandidate(screen, otherScreen, overlapThreshold) && ov >= overlapThreshold
            }

        let sorted = candidates.sorted { s1, s2 in
            distance(screen, s1) < distance(screen, s2)
        }

        return sorted.first
    }

    private static func leftScreen(from screen: NSScreen, in screens: [NSScreen]) -> NSScreen? {
        directionalScreen(
            from: screen,
            in: screens,
            isCandidate: { current, other, threshold in
                other.frame.maxX <= current.frame.minX + threshold
            },
            overlap: { current, other in
                Swift.min(current.frame.maxY, other.frame.maxY) - Swift.max(current.frame.minY, other.frame.minY)
            },
            distance: { current, other in
                current.frame.minX - other.frame.maxX
            }
        )
    }

    private static func rightScreen(from screen: NSScreen, in screens: [NSScreen]) -> NSScreen? {
        directionalScreen(
            from: screen,
            in: screens,
            isCandidate: { current, other, threshold in
                other.frame.minX >= current.frame.maxX - threshold
            },
            overlap: { current, other in
                Swift.min(current.frame.maxY, other.frame.maxY) - Swift.max(current.frame.minY, other.frame.minY)
            },
            distance: { current, other in
                other.frame.minX - current.frame.maxX
            }
        )
    }

    private static func topScreen(from screen: NSScreen, in screens: [NSScreen]) -> NSScreen? {
        directionalScreen(
            from: screen,
            in: screens,
            isCandidate: { current, other, threshold in
                other.frame.minY >= current.frame.maxY - threshold
            },
            overlap: { current, other in
                Swift.min(current.frame.maxX, other.frame.maxX) - Swift.max(current.frame.minX, other.frame.minX)
            },
            distance: { current, other in
                other.frame.minY - current.frame.maxY
            }
        )
    }

    private static func bottomScreen(from screen: NSScreen, in screens: [NSScreen]) -> NSScreen? {
        directionalScreen(
            from: screen,
            in: screens,
            isCandidate: { current, other, threshold in
                other.frame.maxY <= current.frame.minY + threshold
            },
            overlap: { current, other in
                Swift.min(current.frame.maxX, other.frame.maxX) - Swift.max(current.frame.minX, other.frame.minX)
            },
            distance: { current, other in
                current.frame.minY - other.frame.maxY
            }
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
