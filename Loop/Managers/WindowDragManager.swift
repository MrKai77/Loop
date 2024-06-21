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

    func addObservers() {
        leftMouseDraggedMonitor = NSEventMonitor(scope: .all, eventMask: .leftMouseDragged) { _ in
            // Process window (only ONCE during a window drag)
            if self.draggingWindow == nil {
                self.setCurrentDraggingWindow()
            }

            if let window = self.draggingWindow,
               let initialFrame = self.initialWindowFrame,
               self.hasWindowMoved(window.frame, initialFrame) {
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
        }

        leftMouseDraggedMonitor!.start()
        leftMouseUpMonitor!.start()
    }

    private func setCurrentDraggingWindow() {
        guard let screen = NSScreen.screenWithMouse else {
            return
        }

        let mousePosition = NSEvent.mouseLocation.flipY(screen: screen)

        guard
            let draggingWindow = WindowEngine.windowAtPosition(mousePosition),
            !draggingWindow.isAppExcluded
        else {
            return
        }

        self.draggingWindow = draggingWindow
        initialWindowFrame = draggingWindow.frame
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
            window.setSize(initialFrame.size)
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
        guard
            let screen = NSScreen.screenWithMouse
        else {
            return
        }

        DispatchQueue.main.async {
            WindowEngine.resize(window, to: .init(self.direction), on: screen)
            self.direction = .noAction
        }
    }
}
