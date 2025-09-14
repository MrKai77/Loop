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
    private static let cacheValidityDuration: TimeInterval = 0.1
    private static let cacheLock = NSLock()

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

        if let leftScreen = screens.left(from: screen) {
            return leftScreen
        }

        guard canRestartCycle else {
            return nil
        }

        let currentFrame = screen.frame
        let overlapThreshold: CGFloat = 10.0

        let overlappingScreens = screens.filter { otherScreen in
            guard otherScreen != screen else { return false }

            let verticalOverlap = Swift.min(currentFrame.maxY, otherScreen.frame.maxY) -
                Swift.max(currentFrame.minY, otherScreen.frame.minY)
            let hasOverlap = verticalOverlap >= overlapThreshold

            return hasOverlap
        }

        if let rightmostOverlapping = overlappingScreens.max(by: { $0.frame.maxX < $1.frame.maxX }) {
            return rightmostOverlapping
        }

        let fallback = rightmostScreen(in: screens)
        return fallback
    }

    static func rightScreen(from screen: NSScreen, canRestartCycle: Bool = true) -> NSScreen? {
        let screens = getScreensInOrder()

        if let rightScreen = screens.right(from: screen) {
            return rightScreen
        }

        guard canRestartCycle else {
            return nil
        }

        let currentFrame = screen.frame
        let overlapThreshold: CGFloat = 10.0

        let overlappingScreens = screens.filter { otherScreen in
            guard otherScreen != screen else { return false }

            let verticalOverlap = Swift.min(currentFrame.maxY, otherScreen.frame.maxY) -
                Swift.max(currentFrame.minY, otherScreen.frame.minY)
            let hasOverlap = verticalOverlap >= overlapThreshold

            return hasOverlap
        }

        if let leftmostOverlapping = overlappingScreens.min(by: { $0.frame.minX < $1.frame.minX }) {
            return leftmostOverlapping
        }

        let fallback = leftmostScreen(in: screens)
        return fallback
    }

    static func topScreen(from screen: NSScreen, canRestartCycle: Bool = true) -> NSScreen? {
        let screens = getScreensInOrder()

        if let topScreen = screens.top(from: screen) {
            return topScreen
        }

        guard canRestartCycle else {
            return nil
        }

        let currentFrame = screen.frame
        let overlapThreshold: CGFloat = 10.0

        let overlappingScreens = screens.filter { otherScreen in
            guard otherScreen != screen else { return false }

            let horizontalOverlap = Swift.min(currentFrame.maxX, otherScreen.frame.maxX) -
                Swift.max(currentFrame.minX, otherScreen.frame.minX)
            let hasOverlap = horizontalOverlap >= overlapThreshold

            return hasOverlap
        }

        if let bottommostOverlapping = overlappingScreens.max(by: { $0.frame.maxY < $1.frame.maxY }) {
            return bottommostOverlapping
        }

        let fallback = bottommostScreen(in: screens)
        return fallback
        return fallback
    }

    static func bottomScreen(from screen: NSScreen, canRestartCycle: Bool = true) -> NSScreen? {
        let screens = getScreensInOrder()

        if let bottomScreen = screens.bottom(from: screen) {
            return bottomScreen
        }

        guard canRestartCycle else {
            return nil
        }

        let currentFrame = screen.frame
        let overlapThreshold: CGFloat = 10.0

        let overlappingScreens = screens.filter { otherScreen in
            guard otherScreen != screen else { return false }

            let horizontalOverlap = Swift.min(currentFrame.maxX, otherScreen.frame.maxX) -
                Swift.max(currentFrame.minX, otherScreen.frame.minX)
            let hasOverlap = horizontalOverlap >= overlapThreshold

            return hasOverlap
        }

        if let topmostOverlapping = overlappingScreens.min(by: { $0.frame.minY < $1.frame.minY }) {
            return topmostOverlapping
        }

        let fallback = topmostScreen(in: screens)
        return fallback
    }

    // MARK: - Cache Management

    static func invalidateScreenCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        cachedScreens = nil
        cacheTimestamp = nil
        cachedScreenCount = 0
    }

    // MARK: Private

    private static func leftmostScreen(in screens: [NSScreen]) -> NSScreen? {
        screens.min { $0.frame.minX < $1.frame.minX }
    }

    private static func rightmostScreen(in screens: [NSScreen]) -> NSScreen? {
        screens.max { $0.frame.maxX < $1.frame.maxX }
    }

    private static func topmostScreen(in screens: [NSScreen]) -> NSScreen? {
        screens.min { $0.frame.minY < $1.frame.minY }
    }

    private static func bottommostScreen(in screens: [NSScreen]) -> NSScreen? {
        screens.max { $0.frame.maxY < $1.frame.maxY }
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
        cacheLock.lock()
        defer { cacheLock.unlock() }

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

    func left(from item: Element) -> Element? {
        guard let screen = item as? NSScreen else { return nil }
        let currentFrame = screen.frame

        let overlapThreshold: CGFloat = 10.0

        let leftScreens = compactMap { $0 as? NSScreen }
            .filter { otherScreen in
                guard otherScreen != screen else { return false }

                let isToTheLeft = otherScreen.frame.maxX <= currentFrame.minX + overlapThreshold

                let verticalOverlap = Swift.min(currentFrame.maxY, otherScreen.frame.maxY) -
                    Swift.max(currentFrame.minY, otherScreen.frame.minY)
                let hasVerticalOverlap = verticalOverlap >= overlapThreshold

                let isValid = isToTheLeft && hasVerticalOverlap

                return isValid
            }

        let sortedLeftScreens = leftScreens.sorted { screen1, screen2 in
            let distance1 = currentFrame.minX - screen1.frame.maxX
            let distance2 = currentFrame.minX - screen2.frame.maxX
            return distance1 < distance2
        }

        let result = sortedLeftScreens.first as? Element

        return result
    }

    func right(from item: Element) -> Element? {
        guard let screen = item as? NSScreen else { return nil }
        let currentFrame = screen.frame

        let overlapThreshold: CGFloat = 10.0

        let rightScreens = compactMap { $0 as? NSScreen }
            .filter { otherScreen in
                guard otherScreen != screen else { return false }

                let isToTheRight = otherScreen.frame.minX >= currentFrame.maxX - overlapThreshold

                let verticalOverlap = Swift.min(currentFrame.maxY, otherScreen.frame.maxY) -
                    Swift.max(currentFrame.minY, otherScreen.frame.minY)
                let hasVerticalOverlap = verticalOverlap >= overlapThreshold

                let isValid = isToTheRight && hasVerticalOverlap

                return isValid
            }

        let sortedRightScreens = rightScreens.sorted { screen1, screen2 in
            let distance1 = screen1.frame.minX - currentFrame.maxX
            let distance2 = screen2.frame.minX - currentFrame.maxX
            return distance1 < distance2
        }

        let result = sortedRightScreens.first as? Element

        return result
    }

    func top(from item: Element) -> Element? {
        guard let screen = item as? NSScreen else { return nil }
        let currentFrame = screen.frame

        let overlapThreshold: CGFloat = 10.0

        let topScreens = compactMap { $0 as? NSScreen }
            .filter { otherScreen in
                guard otherScreen != screen else { return false }

                let isAbove = otherScreen.frame.minY >= currentFrame.maxY - overlapThreshold

                let horizontalOverlap = Swift.min(currentFrame.maxX, otherScreen.frame.maxX) -
                    Swift.max(currentFrame.minX, otherScreen.frame.minX)
                let hasHorizontalOverlap = horizontalOverlap >= overlapThreshold

                let isValid = isAbove && hasHorizontalOverlap

                return isValid
            }

        let sortedTopScreens = topScreens.sorted { screen1, screen2 in
            let distance1 = screen1.frame.minY - currentFrame.maxY
            let distance2 = screen2.frame.minY - currentFrame.maxY
            return distance1 < distance2
        }

        let result = sortedTopScreens.first as? Element

        return result
    }

    func bottom(from item: Element) -> Element? {
        guard let screen = item as? NSScreen else { return nil }
        let currentFrame = screen.frame

        let overlapThreshold: CGFloat = 10.0

        let bottomScreens = compactMap { $0 as? NSScreen }
            .filter { otherScreen in
                guard otherScreen != screen else { return false }

                let isBelow = otherScreen.frame.maxY <= currentFrame.minY + overlapThreshold

                let horizontalOverlap = Swift.min(currentFrame.maxX, otherScreen.frame.maxX) -
                    Swift.max(currentFrame.minX, otherScreen.frame.minX)
                let hasHorizontalOverlap = horizontalOverlap >= overlapThreshold

                let isValid = isBelow && hasHorizontalOverlap

                return isValid
            }

        let sortedBottomScreens = bottomScreens.sorted { screen1, screen2 in
            let distance1 = currentFrame.minY - screen1.frame.maxY
            let distance2 = currentFrame.minY - screen2.frame.maxY
            return distance1 < distance2
        }

        let result = sortedBottomScreens.first as? Element

        return result
    }
}
