//
//  ScreenManager.swift
//  Loop
//
//  Created by Kai Azim on 2024-01-11.
//

import SwiftUI

class ScreenManager {
    static func screenContaining(_ window: Window) -> NSScreen? {
        let screens = self.getScreensInOrder()
        return self.screenContaining(window, in: screens)
    }

    static func nextScreen(from screen: NSScreen) -> NSScreen? {
        let screens = self.getScreensInOrder()
        guard let nextScreen = screens.next(from: screen) else {
            return nil
        }

        return nextScreen
    }

    static func previousScreen(from screen: NSScreen) -> NSScreen? {
        let screens = self.getScreensInOrder()
        guard let nextScreen = screens.previous(from: screen) else {
            return nil
        }

        return nextScreen
    }

    // MARK: PRIVATE

    private static func screenContaining(_ window: Window, in screens: [NSScreen]) -> NSScreen? {
        guard let firstScreen = screens.first else {
            return nil
        }

        if screens.count == 1 {
            return firstScreen
        }

        guard let currentScreen = self.findScreen(with: window, screens) else {
            return firstScreen
        }

        return currentScreen
    }

    private static func getScreensInOrder() -> [NSScreen] {
        NSScreen.screens
            .sorted(by: { $0.frame.origin.y < $1.frame.origin.y })
            .sorted(by: { $0.frame.origin.x < $1.frame.origin.x })
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
        guard let index = self.firstIndex(of: item) else {
            return nil
        }

        if index + 1 < self.count {
            return self[index + 1]
        }

        return self[0]
    }

    func previous(from item: Element) -> Element? {
        guard let index = self.firstIndex(of: item) else {
            return nil
        }

        if index - 1 >= 0 {
            return self[index - 1]
        }

        return self[self.count - 1]
    }
}
