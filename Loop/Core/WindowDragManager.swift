//
//  WindowDragManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-04.
//

import Defaults
import SwiftUI

@MainActor
final class WindowDragManager {
    static let shared = WindowDragManager()
    private init() {}

    private var draggingWindow: Window?
    private var initialWindowFrame: CGRect?
    private var direction: WindowDirection = .noAction

    private let previewController = PreviewController()

    private var leftMouseDraggedMonitor: PassiveEventMonitor?
    private var leftMouseUpMonitor: PassiveEventMonitor?

    private var determineDraggedWindowTask: Task<(), Never>?

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

    private func leftMouseDragged(_: CGEvent) {
        Task { @MainActor in
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

            previewController.close()
            draggingWindow = nil
        }
    }

    private func setCurrentDraggingWindow() {
        if determineDraggedWindowTask != nil { return }

        determineDraggedWindowTask = Task {
            let mousePosition = NSEvent.mouseLocation.flipY(screen: NSScreen.screens[0])

            do {
                guard
                    let draggingWindow = try WindowUtility.windowAtPosition(mousePosition),
                    !draggingWindow.isAppExcluded
                else {
                    return
                }

                self.draggingWindow = draggingWindow
                initialWindowFrame = draggingWindow.frame

                print("Determined window being dragged: \(draggingWindow)")
            } catch {
                // print("Failed to get window at position: \(error.localizedDescription)")
            }

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
            newWindowFrame = newWindowFrame.pushInside(screen.frame)
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

    private func processSnapAction() {
        guard let screen = NSScreen.screenWithMouse else {
            return
        }

        let mainScreen = NSScreen.screens[0]
        let mousePosition = NSEvent.mouseLocation.flipY(screen: mainScreen)
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

        if !ignoredFrame.contains(mousePosition) {
            // Refresh accent colors in case user has enabled the wallpaper processor
            Task {
                await AccentColorController.shared.refresh()
            }

            direction = WindowDirection.getSnapDirection(
                mouseLocation: mousePosition,
                currentDirection: direction,
                screenFrame: screenFrame,
                ignoredFrame: ignoredFrame
            )

            print("Window snapping direction changed: \(direction)")

            previewController.open(screen: screen, window: nil, startingAction: nil)
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
