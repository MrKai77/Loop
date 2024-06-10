//
//  ScreenManager.swift
//  Loop
//
//  Created by Kai Azim on 2024-01-11.
//

import SwiftUI

class ScreenManager {
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

    // MARK: PRIVATE

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
        NSScreen.screens
            .sorted {
                $0.frame.origin.y < $1.frame.origin.y
            }
            .sorted {
                $0.frame.origin.x < $1.frame.origin.x
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
}

extension Array where Element: Hashable {
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
