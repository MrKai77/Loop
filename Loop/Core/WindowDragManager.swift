//
//  WindowDragManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-04.
//

import Defaults
import OSLog
import SwiftUI

final class WindowDragManager {
    static let shared = WindowDragManager()
    private init() {}

    private let logger = Logger(category: "WindowDragManager")

    private var initialMousePosition: CGPoint?
    private var didPassDragDistanceThreshold: Bool = false
    private var dragDistanceThreshold: CGFloat = 5

    private var draggingWindow: Window?
    private var initialWindowFrame: CGRect?
    private var direction: WindowDirection = .noAction

    private let previewController = PreviewController()

    private var leftMouseDraggedMonitor: PassiveEventMonitor?
    private var leftMouseUpMonitor: PassiveEventMonitor?

    private var determineDraggedWindowTask: Task<(), Never>?

    private var currentMousePosition: CGPoint {
        NSEvent.mouseLocation.flipY(screen: NSScreen.screens[0])
    }

    func addObservers() {
        leftMouseDraggedMonitor = PassiveEventMonitor(
            events: [.leftMouseDragged],
            callback: leftMouseDragged
        )

        leftMouseUpMonitor = PassiveEventMonitor(
            events: [.leftMouseUp],
            callback: leftMouseUp
        )

        leftMouseDraggedMonitor!.start()
        leftMouseUpMonitor!.start()
    }

    private func leftMouseDragged(event _: CGEvent) {
        Task { @MainActor in
            guard let initialMousePosition else {
                initialMousePosition = currentMousePosition
                return
            }

            if !didPassDragDistanceThreshold {
                didPassDragDistanceThreshold = currentMousePosition.distance(to: initialMousePosition) > dragDistanceThreshold

                guard didPassDragDistanceThreshold else {
                    return
                }
            }

            // Process window (only ONCE during a window drag)
            if draggingWindow == nil {
                setCurrentDraggingWindow()
            }

            if let window = draggingWindow,
               let initialFrame = initialWindowFrame,
               hasWindowMoved(window.frame, initialFrame) {
                if Defaults[.restoreWindowFrameOnDrag] {
                    restoreInitialWindowSize(window)
                } else {
                    StashManager.shared.onWindowDragged(window.cgWindowID)
                    WindowRecords.eraseRecords(for: window)
                }

                if Defaults[.windowSnapping] {
                    // Only warp cursor away from top edge if top snap area is enabled
                    if Defaults[.suppressMissionControlOnTopDrag],
                       let frame = NSScreen.main?.displayBounds,
                       let mouseLocation = CGEvent.mouseLocation,
                       mouseLocation.y == frame.minY {
                        let newOrigin = CGPoint(x: mouseLocation.x, y: frame.minY + 1)
                        CGWarpMouseCursorPosition(newOrigin)
                    }

                    processSnapAction()
                }
            }
        }
    }

    private func leftMouseUp(_: CGEvent) {
        Task { @MainActor in
            if let window = draggingWindow,
               let initialFrame = initialWindowFrame,
               hasWindowMoved(window.frame, initialFrame) {
                if Defaults[.windowSnapping] {
                    attemptWindowSnap(window)
                }
            }

            self.previewController.close()
            self.draggingWindow = nil

            previewController.close()
            draggingWindow = nil
        }
    }

    @MainActor
    private func setCurrentDraggingWindow() {
        if determineDraggedWindowTask != nil { return }

        determineDraggedWindowTask = Task {
            guard
                let draggingWindow = try? WindowUtility.windowAtPosition(currentMousePosition),
                !draggingWindow.isAppExcluded
            else {
                return
            }

            self.draggingWindow = draggingWindow
            initialWindowFrame = draggingWindow.frame

            logger.info("Determined window being dragged: \(draggingWindow.debugDescription)")

            determineDraggedWindowTask = nil
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
            newWindowFrame = newWindowFrame.pushInside(screen.displayBounds)
            window.setFrame(newWindowFrame)
        } else {
            window.size = initialFrame.size
        }

        // If the window doesn't contain the cursor, keep the original maxX
        if !window.frame.contains(currentMousePosition) {
            var newFrame = window.frame

            newFrame.origin.x = startFrame.maxX - newFrame.width
            window.setFrame(newFrame)

            // If it still doesn't contain the cursor, move the window to be centered with the cursor
            if !newFrame.contains(currentMousePosition) {
                newFrame.origin.x = currentMousePosition.x - (newFrame.width / 2)
                window.setFrame(newFrame)
            }
        }

        WindowRecords.eraseRecords(for: window)
    }

    private func processSnapAction() {
        guard let screen = NSScreen.screenWithMouse else {
            return
        }

        let mainScreen = NSScreen.screens[0]
        let screenFrame = screen.frame.flipY(screen: mainScreen)

        previewController.setScreen(to: screen)

        let inset = Defaults[.snapThreshold]
        let topInset = max(screen.menubarHeight / 2, inset)
        var ignoredFrame = screenFrame

        ignoredFrame.origin.x += inset
        ignoredFrame.size.width -= inset * 2
        ignoredFrame.origin.y += topInset
        ignoredFrame.size.height -= inset + topInset

        let oldDirection = direction

        if !ignoredFrame.contains(currentMousePosition) {
            // Refresh accent colors in case user has enabled the wallpaper processor
            Task {
                await AccentColorController.shared.refresh()
            }

            direction = WindowDirection.getSnapDirection(
                mouseLocation: currentMousePosition,
                currentDirection: direction,
                screenFrame: screenFrame,
                ignoredFrame: ignoredFrame
            )

            // swiftformat:disable:next redundantSelf
            logger.info("Window snapping direction changed: \(self.direction.debugDescription)")

            previewController.open(screen: screen, window: draggingWindow, startingAction: nil)
            previewController.setAction(to: WindowAction(direction))
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
