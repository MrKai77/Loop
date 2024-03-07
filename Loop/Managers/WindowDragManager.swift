//
//  WindowDragManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-04.
//

import Cocoa
import Defaults

class WindowDragManager {

    private var draggingWindow: Window?
    private var initialWindowFrame: CGRect?
    private var direction: WindowDirection = .noAction

    private let previewController = PreviewController()

    private var leftMouseDraggedMonitor: EventMonitor?
    private var leftMouseUpMonitor: EventMonitor?

    func addObservers() {
        self.leftMouseDraggedMonitor = NSEventMonitor(scope: .global, eventMask: .leftMouseDragged) { _ in
            // Process window (only ONCE during a window drag)
            if self.draggingWindow == nil {
                self.setCurrentDraggingWindow()
            }

            if let window = self.draggingWindow,
               let initialFrame = self.initialWindowFrame,
               self.hasWindowMoved(window.frame, initialFrame) {
                // If window is not at initial position...

                if Defaults[.restoreWindowFrameOnDrag] {
                    self.restoreInitialWindowSize(window)
                }

                if Defaults[.windowSnapping] {
                    self.getWindowSnapDirection()
                }
            }
        }

        self.leftMouseUpMonitor = NSEventMonitor(scope: .global, eventMask: .leftMouseUp) { _ in
            if let window = self.draggingWindow,
               let initialFrame = self.initialWindowFrame,
               self.hasWindowMoved(window.frame, initialFrame) {
                // If window is not at initial position...

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
        guard let mousePosition = NSEvent.mouseLocation.flipY,
              let draggingWindow = WindowEngine.windowAtPosition(mousePosition) else {
            return
        }
        self.draggingWindow = draggingWindow
        self.initialWindowFrame = draggingWindow.frame
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
        guard
            let mousePosition = NSEvent.mouseLocation.flipY,
            let screen = NSScreen.screenWithMouse,
            let screenFrame = screen.visibleFrame.flipY
        else {
            return
        }

        self.previewController.setScreen(to: screen)
        let ignoredFrame = screenFrame.insetBy(dx: 20, dy: 20)  // 10px of snap area on each side

        let oldDirection = self.direction

        if !ignoredFrame.contains(mousePosition) {
            self.direction = WindowDirection.processSnap(
                mouseLocation: mousePosition,
                currentDirection: self.direction,
                screenFrame: screenFrame,
                ignoredFrame: ignoredFrame
            )

            print("Window snapping direction changed: \(direction)")

            self.previewController.open(screen: screen, window: nil)
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name.updateUIDirection,
                    object: nil,
                    userInfo: ["action": WindowAction(self.direction)]
                )
            }
        } else {
            self.direction = .noAction
            self.previewController.close()
        }

        if self.direction != oldDirection {
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
        }
    }
}
