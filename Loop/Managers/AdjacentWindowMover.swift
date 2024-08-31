//
//  AdjacentWindowMover.swift
//  Loop
//
//  Created by Kai Azim on 2024-08-31.
//

import Defaults
import SwiftUI

class AdjacentWindowMover {
    static var shared = AdjacentWindowMover()

    private init() {}

    private var mainWindow: Window?
//    private var mainWindowInitialFrame: CGRect?

    // Using set to prevent duplicates
    private var topAdjacentWindows: [AjacentWindowState] = []
    private var bottomAdjacentWindows: [AjacentWindowState] = []
    private var leadingAdjacentWindows: [AjacentWindowState] = []
    private var trailingAdjacentWindows: [AjacentWindowState] = []

    let windowSpacing = Defaults[.enablePadding] ? Defaults[.padding].window : 0

    private var eventMonitor: EventMonitor?

    func addObservers() {
        eventMonitor = NSEventMonitor(scope: .global, eventMask: [.leftMouseDragged, .leftMouseUp]) { event in
            if event.type == .leftMouseDragged {
                self.handler()
            } else {
                self.mainWindow = nil

                self.topAdjacentWindows = []
                self.bottomAdjacentWindows = []
                self.leadingAdjacentWindows = []
                self.trailingAdjacentWindows = []
            }
            return nil
        }

        eventMonitor!.start()
    }

    private func handler() {
        if mainWindow == nil,
           let window = try? WindowEngine.getFrontmostWindow() {
            mainWindow = window
//            mainWindowInitialFrame = window.frame
        }

        guard let mainWindow else { return }
        getAdjacentWindows()

        moveTopAdjacentWindows()
        moveBottomAdjacentWindows()
        moveLeadingAdjacentWindows()
        moveTrailingAdjacentWindows()
    }
}

private extension AdjacentWindowMover {
    class AjacentWindowState: Equatable, Hashable {
        let window: Window
        let initialFrame: CGRect

        var preview: PreviewController?

        init(_ window: Window) {
            self.window = window
            self.initialFrame = window.frame
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(window.cgWindowID)
        }

        static func == (lhs: AjacentWindowState, rhs: AjacentWindowState) -> Bool {
            lhs.window.cgWindowID == rhs.window.cgWindowID
        }
    }

    func getAdjacentWindows() {
        guard let window = mainWindow else { return }
        let frame = window.frame

        let windows = WindowEngine.windowList
        let currentScreen = NSScreen.screenWithMouse ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = currentScreen.frame

        // Top
        let topWindows = windows.filter { $0.frame.maxY.approximatelyEquals(to: frame.minY, tolerance: 100) }
        for target in topWindows where target.cgWindowID != window.cgWindowID && screenFrame.contains(target.frame) && !topAdjacentWindows.contains(where: { $0.window.cgWindowID == target.cgWindowID }) {
            topAdjacentWindows.append(.init(target))
        }

        // Bottom
        let bottomWindows = windows.filter { $0.frame.minY.approximatelyEquals(to: frame.maxY, tolerance: 100) }
        for target in bottomWindows where target.cgWindowID != window.cgWindowID && screenFrame.contains(target.frame) && !bottomAdjacentWindows.contains(where: { $0.window.cgWindowID == target.cgWindowID }) {
            bottomAdjacentWindows.append(.init(target))
        }

        // Leading
        let leadingWindows = windows.filter { $0.frame.maxX.approximatelyEquals(to: frame.minX, tolerance: 100) }
        for target in leadingWindows where target.cgWindowID != window.cgWindowID && screenFrame.contains(target.frame) && !leadingAdjacentWindows.contains(where: { $0.window.cgWindowID == target.cgWindowID }) {
            leadingAdjacentWindows.append(.init(target))
        }

        // Trailing
        let trailingWindows = windows.filter { $0.frame.minX.approximatelyEquals(to: frame.maxX, tolerance: 100) }
        for target in trailingWindows where target.cgWindowID != window.cgWindowID && screenFrame.contains(target.frame) && !trailingAdjacentWindows.contains(where: { $0.window.cgWindowID == target.cgWindowID }) {
            trailingAdjacentWindows.append(.init(target))
        }
    }

    func moveTopAdjacentWindows() {
        guard let window = mainWindow else { return }
        let frame = window.frame

        for item in topAdjacentWindows {
            let newOrigin = CGPoint(x: window.frame.minX, y: item.initialFrame.minY)
            let newSize = CGSize(width: window.frame.width, height: frame.maxY - frame.height - item.initialFrame.minY - windowSpacing)
            item.window.setFrame(.init(origin: newOrigin, size: newSize))
        }
    }

    func moveBottomAdjacentWindows() {
        guard let window = mainWindow else { return }
        let frame = window.frame

        for item in bottomAdjacentWindows {
            let newOrigin = window.frame.bottomLeftPoint
            let newSize = CGSize(width: window.frame.width, height: item.initialFrame.maxY - frame.maxY - windowSpacing)
            item.window.setFrame(.init(origin: newOrigin, size: newSize))
        }
    }

    func moveLeadingAdjacentWindows() {
        guard let window = mainWindow else { return }
        let frame = window.frame

        for item in leadingAdjacentWindows {
            let newOrigin = CGPoint(x: item.initialFrame.minX, y: window.frame.minY)
            let newSize = CGSize(width: frame.maxX - frame.width - item.initialFrame.minX - windowSpacing, height: window.frame.height)
            item.window.setFrame(.init(origin: newOrigin, size: newSize))
        }
    }

    func moveTrailingAdjacentWindows() {
        guard let window = mainWindow else { return }
        let frame = window.frame

        for item in trailingAdjacentWindows {
            let newOrigin = window.frame.topRightPoint
            let newSize = CGSize(width: item.initialFrame.maxX - frame.maxX - windowSpacing, height: window.frame.height)
            item.window.setFrame(.init(origin: newOrigin, size: newSize))
        }
    }
}
