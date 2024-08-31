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
    private var mainWindowInitialFrame: CGRect?
    private var lastResizedTime: Date = .now

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
                self.mainWindowInitialFrame = nil
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
            mainWindowInitialFrame = window.frame
            getAdjacentWindows()
        }
        moveAdjacentWindows()
    }
}

private extension AdjacentWindowMover {
    struct AjacentWindowState: Equatable, Hashable {
        let window: Window
        let initialFrame: CGRect

        var shouldAdjustWidth: Bool
        var shouldAdjustHeight: Bool

        init(_ window: Window, initialFrame: CGRect, shouldAlsoAdjustWidth: Bool = false, shouldAlsoAdjustHeight: Bool = false) {
            self.window = window
            self.initialFrame = initialFrame

            self.shouldAdjustHeight = shouldAlsoAdjustHeight
            self.shouldAdjustWidth = shouldAlsoAdjustWidth
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
        for target in topWindows where target.cgWindowID != window.cgWindowID && !topAdjacentWindows.contains(where: { $0.window.cgWindowID == target.cgWindowID }) {
            let itemFrame = target.frame
            if screenFrame.contains(itemFrame) {
                let shouldAdjustWidth = abs(itemFrame.minX - frame.minX) < 20 && abs(itemFrame.maxX - frame.maxX) < 20
                topAdjacentWindows.append(.init(target, initialFrame: itemFrame, shouldAlsoAdjustWidth: shouldAdjustWidth))
            }
        }

        // Bottom
        let bottomWindows = windows.filter { $0.frame.minY.approximatelyEquals(to: frame.maxY, tolerance: 100) }
        for target in bottomWindows where target.cgWindowID != window.cgWindowID && !bottomAdjacentWindows.contains(where: { $0.window.cgWindowID == target.cgWindowID }) {
            let itemFrame = target.frame
            if screenFrame.contains(itemFrame) {
                let shouldAdjustWidth = abs(itemFrame.minX - frame.minX) < 20 && abs(itemFrame.maxX - frame.maxX) < 20
                bottomAdjacentWindows.append(.init(target, initialFrame: itemFrame, shouldAlsoAdjustWidth: shouldAdjustWidth))
            }
        }

        // Leading
        let leadingWindows = windows.filter { $0.frame.maxX.approximatelyEquals(to: frame.minX, tolerance: 100) }
        for target in leadingWindows where target.cgWindowID != window.cgWindowID && !leadingAdjacentWindows.contains(where: { $0.window.cgWindowID == target.cgWindowID }) {
            let itemFrame = target.frame
            if screenFrame.contains(itemFrame) {
                let shouldAdjustHeight = abs(itemFrame.minY - frame.minY) < 20 && abs(itemFrame.maxY - frame.maxY) < 20
                leadingAdjacentWindows.append(.init(target, initialFrame: itemFrame, shouldAlsoAdjustHeight: shouldAdjustHeight))
            }
        }

        // Trailing
        let trailingWindows = windows.filter { $0.frame.minX.approximatelyEquals(to: frame.maxX, tolerance: 100) }
        for target in trailingWindows where target.cgWindowID != window.cgWindowID && !trailingAdjacentWindows.contains(where: { $0.window.cgWindowID == target.cgWindowID }) {
            let itemFrame = target.frame
            if screenFrame.contains(itemFrame) {
                let shouldAdjustHeight = abs(itemFrame.minY - frame.minY) < 20 && abs(itemFrame.maxY - frame.maxY) < 20
                trailingAdjacentWindows.append(.init(target, initialFrame: itemFrame, shouldAlsoAdjustHeight: shouldAdjustHeight))
            }
        }
    }

    func moveAdjacentWindows() {
        guard Date.now.timeIntervalSince(lastResizedTime) > 0.1 else { return }
        lastResizedTime = .now

        moveTopAdjacentWindows()
        moveBottomAdjacentWindows()
        moveLeadingAdjacentWindows()
        moveTrailingAdjacentWindows()
    }

    func moveTopAdjacentWindows() {
        guard let frame = mainWindow?.frame else { return }

        for item in topAdjacentWindows {
            let shouldAdjustWidth = item.shouldAdjustWidth
            let newOrigin = CGPoint(x: shouldAdjustWidth ? frame.minX : item.initialFrame.minX, y: item.initialFrame.minY)
            let newSize = CGSize(width: shouldAdjustWidth ? frame.width : item.initialFrame.width, height: frame.maxY - frame.height - item.initialFrame.minY - windowSpacing)
            item.window.setFrame(.init(origin: newOrigin, size: newSize))
        }
    }

    func moveBottomAdjacentWindows() {
        guard let frame = mainWindow?.frame else { return }

        for item in bottomAdjacentWindows {
            let shouldAdjustWidth = item.shouldAdjustWidth
            let newOrigin = CGPoint(x: shouldAdjustWidth ? frame.minX : item.initialFrame.minX, y: frame.maxY + windowSpacing)
            let newSize = CGSize(width: shouldAdjustWidth ? frame.width : item.initialFrame.width, height: item.initialFrame.maxY - frame.maxY)
            item.window.setFrame(.init(origin: newOrigin, size: newSize))
        }
    }

    func moveLeadingAdjacentWindows() {
        guard let frame = mainWindow?.frame else { return }

        for item in leadingAdjacentWindows {
            let shouldAdjustHeight = item.shouldAdjustHeight
            let newOrigin = CGPoint(x: item.initialFrame.minX, y: shouldAdjustHeight ? frame.minY : item.initialFrame.minY)
            let newSize = CGSize(width: frame.maxX - frame.width - item.initialFrame.minX - windowSpacing, height: shouldAdjustHeight ? frame.height : item.initialFrame.height)
            item.window.setFrame(.init(origin: newOrigin, size: newSize))
        }
    }

    func moveTrailingAdjacentWindows() {
        guard let frame = mainWindow?.frame else { return }

        for item in trailingAdjacentWindows {
            let shouldAdjustHeight = item.shouldAdjustHeight
            let newOrigin = CGPoint(x: frame.maxX, y: shouldAdjustHeight ? frame.minY : item.initialFrame.minY)
            let newSize = CGSize(width: item.initialFrame.maxX - frame.maxX - windowSpacing, height: shouldAdjustHeight ? frame.height : item.initialFrame.height)
            item.window.setFrame(.init(origin: newOrigin, size: newSize))
        }
    }
}
