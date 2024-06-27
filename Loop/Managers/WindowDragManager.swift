//
//  WindowDragManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-04.
//

import Defaults
import SwiftUI

class WindowDragManager {
    private var draggingWindow: Window?
    private var initialWindowFrame: CGRect?
    private var direction: WindowDirection = .noAction

    private let previewController = PreviewController()

    private var leftMouseDraggedMonitor: EventMonitor?
    private var leftMouseUpMonitor: EventMonitor?

    private var adjacentWindows: [AjacentWindowState] = [] // Window, then its initial frame
    private var resizedSide: Edge?

    struct AjacentWindowState {
        let window: Window
        let initialFrame: CGRect

        init(_ window: Window) {
            self.window = window
            self.initialFrame = window.frame
        }
    }

    func addObservers() {
        leftMouseDraggedMonitor = NSEventMonitor(scope: .global, eventMask: .leftMouseDragged) { _ in
            // Process window (only ONCE during a window drag)
            if self.draggingWindow == nil {
                self.setCurrentDraggingWindow()
            }

            if let window = self.draggingWindow,
               let initialFrame = self.initialWindowFrame {
                let frame = window.frame
                let windowSpacing = Defaults[.enablePadding] ? Defaults[.padding].window : 0

                if frame != initialFrame {
                    if self.resizedSide == nil {
                        if !frame.maxX.approximatelyEquals(to: initialFrame.maxX), frame.minX.approximatelyEquals(to: initialFrame.minX) {
                            self.resizedSide = .trailing
                        }

                        if !frame.minX.approximatelyEquals(to: initialFrame.minX), frame.maxX.approximatelyEquals(to: initialFrame.maxX) {
                            self.resizedSide = .leading
                        }

                        if !frame.maxY.approximatelyEquals(to: initialFrame.maxY), frame.minY.approximatelyEquals(to: initialFrame.minY) {
                            self.resizedSide = .bottom
                        }

                        if !frame.minY.approximatelyEquals(to: initialFrame.minY), frame.maxY.approximatelyEquals(to: initialFrame.maxY) {
                            self.resizedSide = .top
                        }
                    }

                    if let resizedSide = self.resizedSide {
                        if resizedSide == .trailing {
                            if self.adjacentWindows.isEmpty {
                                let windows = WindowEngine.windowList
                                let targetWindows = windows.filter { $0.frame.minX.approximatelyEquals(to: frame.maxX, tolerance: 100) }

                                for target in targetWindows where target.cgWindowID != window.cgWindowID {
                                    self.adjacentWindows.append(.init(target))
                                }
                            } else {
                                for item in self.adjacentWindows {
                                    let newOrigin = CGPoint(x: frame.maxX + windowSpacing, y: item.initialFrame.minY)
                                    let newSize = CGSize(width: item.initialFrame.maxX - frame.maxX - windowSpacing, height: item.initialFrame.height)
                                    item.window.setFrame(.init(origin: newOrigin, size: newSize))
                                }
                            }
                        }

                        if resizedSide == .leading {
                            if self.adjacentWindows.isEmpty {
                                let windows = WindowEngine.windowList
                                let targetWindows = windows.filter { $0.frame.maxX.approximatelyEquals(to: frame.minX, tolerance: 100) }

                                for target in targetWindows where target.cgWindowID != window.cgWindowID {
                                    self.adjacentWindows.append(.init(target))
                                }
                            } else {
                                for item in self.adjacentWindows {
                                    let newOrigin = item.initialFrame.origin
                                    let newSize = CGSize(width: frame.maxX - frame.width - item.initialFrame.minX - windowSpacing, height: item.initialFrame.height)
                                    item.window.setFrame(.init(origin: newOrigin, size: newSize))
                                }
                            }
                        }

                        if resizedSide == .bottom {
                            if self.adjacentWindows.isEmpty {
                                let windows = WindowEngine.windowList
                                let targetWindows = windows.filter { $0.frame.minY.approximatelyEquals(to: frame.maxY, tolerance: 100) }

                                for target in targetWindows where target.cgWindowID != window.cgWindowID {
                                    self.adjacentWindows.append(.init(target))
                                }
                            } else {
                                for item in self.adjacentWindows {
                                    let newOrigin = CGPoint(x: item.initialFrame.minX, y: frame.maxY + windowSpacing)
                                    let newSize = CGSize(width: item.initialFrame.width, height: item.initialFrame.maxY - frame.maxY - windowSpacing)
                                    item.window.setFrame(.init(origin: newOrigin, size: newSize))
                                }
                            }
                        }

                        if resizedSide == .top {
                            if self.adjacentWindows.isEmpty {
                                let windows = WindowEngine.windowList
                                let targetWindows = windows.filter { $0.frame.maxY.approximatelyEquals(to: frame.minY, tolerance: 100) }

                                for target in targetWindows where target.cgWindowID != window.cgWindowID {
                                    self.adjacentWindows.append(.init(target))
                                }
                            } else {
                                for item in self.adjacentWindows {
                                    let newOrigin = item.initialFrame.origin
                                    let newSize = CGSize(width: item.initialFrame.width, height: frame.maxY - frame.height - item.initialFrame.minY - windowSpacing)
                                    item.window.setFrame(.init(origin: newOrigin, size: newSize))
                                }
                            }
                        }
                    }

                    return // Don't restore initial window frame
                }

                if self.hasWindowMoved(window.frame, initialFrame) {
                    if Defaults[.restoreWindowFrameOnDrag] {
                        self.restoreInitialWindowSize(window)
                    } else {
                        WindowRecords.eraseRecords(for: window)
                    }

                    if Defaults[.windowSnapping] {
                        if let frame = NSScreen.main?.displayBounds,
                           let mouseLocation = CGEvent.mouseLocation {
                            if mouseLocation.y == frame.minY {
                                let newOrigin = CGPoint(x: mouseLocation.x, y: frame.minY + 1)
                                CGWarpMouseCursorPosition(newOrigin)
                            }
                        }

                        self.getWindowSnapDirection()
                    }
                }
            }
        }

        leftMouseUpMonitor = NSEventMonitor(scope: .global, eventMask: .leftMouseUp) { _ in
            if let window = self.draggingWindow,
               let initialFrame = self.initialWindowFrame,
               self.hasWindowMoved(window.frame, initialFrame) {
                if Defaults[.windowSnapping] {
                    self.attemptWindowSnap(window)
                }
            }

            self.previewController.close()
            self.draggingWindow = nil

            self.adjacentWindows = []
            self.resizedSide = nil
        }

        leftMouseDraggedMonitor!.start()
        leftMouseUpMonitor!.start()
    }

    private func setCurrentDraggingWindow() {
//        guard let screen = NSScreen.screenWithMouse else {
//            return
//        }

//        let mousePosition = NSEvent.mouseLocation.flipY(screen: screen)

        do {
            guard
//                let draggingWindow = try WindowEngine.windowAtPosition(mousePosition),
                let draggingWindow = try WindowEngine.getFrontmostWindow(),
                !draggingWindow.isAppExcluded
            else {
                return
            }

            self.draggingWindow = draggingWindow
            initialWindowFrame = draggingWindow.frame
        } catch {
            print("Failed to get window at position: \(error.localizedDescription)")
        }
    }

    private func hasWindowMoved(_ windowFrame: CGRect, _ initialFrame: CGRect) -> Bool {
        !initialFrame.topLeftPoint.approximatelyEqual(to: windowFrame.topLeftPoint) &&
            !initialFrame.topRightPoint.approximatelyEqual(to: windowFrame.topRightPoint) &&
            !initialFrame.bottomLeftPoint.approximatelyEqual(to: windowFrame.bottomLeftPoint) &&
            !initialFrame.bottomRightPoint.approximatelyEqual(to: windowFrame.bottomRightPoint)
    }

    private func restoreInitialWindowSize(_ window: Window) {
        let startFrame = window.frame

        guard let initialFrame = WindowRecords.getInitialFrame(for: window) else {
            return
        }

        if let screen = NSScreen.screenWithMouse {
            var newWindowFrame = window.frame
            newWindowFrame.size = initialFrame.size
            newWindowFrame = newWindowFrame.pushBottomRightPointInside(screen.frame)
            window.setFrame(newWindowFrame)
        } else {
            window.size = initialFrame.size
        }

        // If the window doesn't contain the cursor, keep the original maxX
        if let cursorLocation = CGEvent.mouseLocation, !window.frame.contains(cursorLocation) {
            var newFrame = window.frame

            newFrame.origin.x = startFrame.maxX - newFrame.width
            window.setFrame(newFrame)

            // If it still doesn't contain the cursor, move the window to be centered with the cursor
            if !newFrame.contains(cursorLocation) {
                newFrame.origin.x = cursorLocation.x - (newFrame.width / 2)
                window.setFrame(newFrame)
            }
        }

        WindowRecords.eraseRecords(for: window)
    }

    private func getWindowSnapDirection() {
        guard let screen = NSScreen.screenWithMouse else {
            return
        }
        let mousePosition = NSEvent.mouseLocation.flipY(maxY: screen.frame.maxY)
        let screenFrame = screen.frame.flipY(maxY: screen.frame.maxY)

        previewController.setScreen(to: screen)

        let insets: CGFloat = 2
        let topInset = screen.menubarHeight / 2
        var ignoredFrame = screenFrame

        ignoredFrame.origin.x += insets
        ignoredFrame.size.width -= insets * 2
        ignoredFrame.origin.y += topInset
        ignoredFrame.size.height -= insets + topInset

        let oldDirection = direction

        if !ignoredFrame.contains(mousePosition) {
            direction = WindowDirection.processSnap(
                mouseLocation: mousePosition,
                currentDirection: direction,
                screenFrame: screenFrame,
                ignoredFrame: ignoredFrame
            )

            print("Window snapping direction changed: \(direction)")

            previewController.open(screen: screen, window: nil)

            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name.updateUIDirection,
                    object: nil,
                    userInfo: ["action": WindowAction(self.direction)]
                )
            }
        } else {
            direction = .noAction
            previewController.close()
        }

        if direction != oldDirection {
            if Defaults[.hapticFeedback] {
                NSHapticFeedbackManager.defaultPerformer.perform(
                    NSHapticFeedbackManager.FeedbackPattern.alignment,
                    performanceTime: NSHapticFeedbackManager.PerformanceTime.now
                )
            }
        }
    }

    private func attemptWindowSnap(_ window: Window) {
        guard let screen = NSScreen.screenWithMouse else {
            return
        }

        DispatchQueue.main.async {
            WindowEngine.resize(window, to: .init(self.direction), on: screen)
            self.direction = .noAction
        }
    }
}
