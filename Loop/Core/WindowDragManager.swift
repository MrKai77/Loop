//
//  WindowDragManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-04.
//

import Defaults
import os
import Scribe
import SwiftUI

@Loggable
@MainActor
final class WindowDragManager {
    static let shared = WindowDragManager()
    private init() {}

    private var resizeContext: ResizeContext?
    private var initialWindowFrame: CGRect?

    /// This is to avoid repeated window resolution attempts during a non-window drag (e.g. in games).
    private var didFailToResolveDraggedWindow: Bool = false

    private let previewController = PreviewController()

    /// Active (not listen-only) so we can rewrite top-edge drag events before macOS handles them.
    /// See `nudgeEventOffTopEdge(_:)` — this replaces cursor warping, which caused stutter (#609).
    private var leftMouseDraggedMonitor: ActiveEventMonitor?
    private var leftMouseUpMonitor: PassiveEventMonitor?

    private var determineDraggedWindowTask: Task<(), Never>?
    private var accessibilityCheckerTask: Task<(), Never>?

    /// Whether the current window drag should keep Mission Control from opening.
    ///
    /// The drag callback runs on the event-tap thread, while window resolution happens on the
    /// main actor, so this flag is shared through a lock (same pattern as `LoopManager`).
    private let shouldSuppressMissionControlOnDrag = OSAllocatedUnfairLock(initialState: false)
    nonisolated private var isSuppressingMissionControl: Bool {
        shouldSuppressMissionControlOnDrag.withLock { $0 }
    }

    private var currentMousePosition: CGPoint {
        NSEvent.mouseLocation.flipY(screen: NSScreen.screens[0])
    }

    /// This is to avoid running global drag logic unless a feature actually depends on it.
    private var shouldMonitorDragActions: Bool {
        Defaults[.windowSnapping] ||
            Defaults[.restoreWindowFrameOnDrag] ||
            !Defaults[.stashManagerStashedWindows].isEmpty
    }

    func addObservers() {
        accessibilityCheckerTask = Task(priority: .background) { [weak self] in
            for await status in AccessibilityManager.shared.stream(initial: true) {
                guard let self, !Task.isCancelled else {
                    return
                }

                if status {
                    setupListeners()
                } else {
                    removeListeners()
                }
            }
        }
    }

    func shutdown() {
        accessibilityCheckerTask?.cancel()
        accessibilityCheckerTask = nil
        removeListeners()
        resetDragState()
        previewController.close()
    }

    private func setupListeners() {
        removeListeners()

        let leftMouseDraggedMonitor = ActiveEventMonitor(
            "snapping_left_mouse_dragged_monitor",
            events: [.leftMouseDragged]
        ) { [weak self] event -> Unmanaged<CGEvent>? in
            guard let self else {
                return Unmanaged.passUnretained(event)
            }

            // If suppress is enabled for this drag, shift the event 1px off the top edge
            // before it reaches the system (prevents Mission Control without warping the cursor).
            if isSuppressingMissionControl {
                Self.nudgeEventOffTopEdge(event)
            }

            leftMouseDragged(event: event)
            return Unmanaged.passUnretained(event)
        }

        let leftMouseUpMonitor = PassiveEventMonitor(
            "snapping_left_mouse_up_monitor",
            events: [.leftMouseUp],
            callback: leftMouseUp
        )

        leftMouseDraggedMonitor.start()
        leftMouseUpMonitor.start()

        self.leftMouseDraggedMonitor = leftMouseDraggedMonitor
        self.leftMouseUpMonitor = leftMouseUpMonitor
    }

    private func removeListeners() {
        leftMouseUpMonitor?.stop()
        leftMouseDraggedMonitor?.stop()

        leftMouseUpMonitor = nil
        leftMouseDraggedMonitor = nil
    }

    /// Keeps Mission Control from opening during a top-edge window snap.
    ///
    /// macOS opens Mission Control when a window drag stays on the top screen edge.
    /// We rewrite that event so its reported Y is 1px below the edge. Mutating the event
    /// is smoother than `CGWarpMouseCursorPosition`, which fights the real cursor every frame.
    private nonisolated static func nudgeEventOffTopEdge(_ event: CGEvent) {
        let location = event.location

        // CGEvent locations use display coordinates (`NSScreen.displayBounds`), not AppKit frames.
        let screenBounds = NSScreen.screens
            .map(\.displayBounds)
            .first { bounds in
                location.x >= bounds.minX &&
                    location.x <= bounds.maxX &&
                    location.y >= bounds.minY &&
                    location.y <= bounds.maxY
            } ?? NSScreen.main?.displayBounds

        // Top edge in these coordinates is `minY` (origin is top-left of the main display).
        guard let bounds = screenBounds, location.y <= bounds.minY else {
            return
        }

        var adjusted = location
        adjusted.y = bounds.minY + 1
        event.location = adjusted
    }

    private func leftMouseDragged(event _: CGEvent) {
        guard shouldMonitorDragActions else {
            return
        }

        Task {
            // Process window (only ONCE during a window drag)
            if resizeContext == nil, !didFailToResolveDraggedWindow {
                setCurrentDraggingWindow()
            }

            if let window = resizeContext?.window,
               let initialFrame = initialWindowFrame,
               hasWindowResized(window.frame, initialFrame) {
                if hasWindowMoved(window.frame, initialFrame) {
                    if Defaults[.restoreWindowFrameOnDrag] {
                        await restoreInitialWindowSize(window)
                    }

                    if Defaults[.windowSnapping] {
                        processSnapAction()
                    }
                }

                StashManager.shared.onWindowManipulated(window.cgWindowID)
                await WindowRecords.shared.eraseRecords(for: window)
            }
        }
    }

    private func leftMouseUp(_: CGEvent) {
        guard Defaults[.windowSnapping] else {
            return
        }

        Task {
            previewController.close()

            if let context = resizeContext,
               !context.action.direction.isNoOp,
               let window = context.window,
               let initialFrame = initialWindowFrame,
               hasWindowMoved(window.frame, initialFrame) {
                do {
                    _ = try await WindowActionEngine.shared.apply(context: context)
                } catch {
                    log.error("Failed to snap window: \(error.localizedDescription)")
                }
            }

            resetDragState()
        }
    }

    private func setCurrentDraggingWindow() {
        guard determineDraggedWindowTask == nil else {
            return
        }

        determineDraggedWindowTask = Task {
            defer {
                determineDraggedWindowTask = nil
            }

            guard let window = WindowUtility.windowAtPosition(currentMousePosition),
                  !window.isAppExcluded
            else {
                didFailToResolveDraggedWindow = true
                return
            }

            initialWindowFrame = window.frame

            let context = ResizeContext(
                window: window,
                initialMousePosition: currentMousePosition
            )
            await context.refreshResolvedState()
            self.resizeContext = context

            // Enable Mission Control suppression for the rest of this drag when the setting allows it.
            shouldSuppressMissionControlOnDrag.withLock {
                $0 = Defaults[.windowSnapping] && Defaults[.suppressMissionControlOnTopDrag]
            }

            log.info("Determined window being dragged: \(window.description)")
        }
    }

    private func resetDragState() {
        resizeContext = nil
        didFailToResolveDraggedWindow = false
        initialWindowFrame = nil
        determineDraggedWindowTask?.cancel()
        determineDraggedWindowTask = nil
        shouldSuppressMissionControlOnDrag.withLock { $0 = false }
    }

    private func hasWindowMoved(_ windowFrame: CGRect, _ initialFrame: CGRect) -> Bool {
        !initialFrame.topLeftPoint.approximatelyEqual(to: windowFrame.topLeftPoint) &&
            !initialFrame.topRightPoint.approximatelyEqual(to: windowFrame.topRightPoint) &&
            !initialFrame.bottomLeftPoint.approximatelyEqual(to: windowFrame.bottomLeftPoint) &&
            !initialFrame.bottomRightPoint.approximatelyEqual(to: windowFrame.bottomRightPoint)
    }

    private func hasWindowResized(_ windowFrame: CGRect, _ initialFrame: CGRect) -> Bool {
        !initialFrame.topLeftPoint.approximatelyEqual(to: windowFrame.topLeftPoint) ||
            !initialFrame.topRightPoint.approximatelyEqual(to: windowFrame.topRightPoint) ||
            !initialFrame.bottomLeftPoint.approximatelyEqual(to: windowFrame.bottomLeftPoint) ||
            !initialFrame.bottomRightPoint.approximatelyEqual(to: windowFrame.bottomRightPoint)
    }

    private func restoreInitialWindowSize(_ window: Window) async {
        let startFrame = window.frame

        guard let initialFrame = await WindowRecords.shared.getInitialFrame(for: window) else {
            return
        }

        if let screen = NSScreen.screenWithMouse {
            var newWindowFrame = window.frame
            newWindowFrame.size = initialFrame.size
            newWindowFrame = newWindowFrame.pushInside(screen.displayBounds)
            await window.setFrame(newWindowFrame)
        } else {
            window.setSize(initialFrame.size)
        }

        // If the window doesn't contain the cursor, keep the original maxX
        if !window.frame.contains(currentMousePosition) {
            var newFrame = window.frame

            newFrame.origin.x = startFrame.maxX - newFrame.width
            await window.setFrame(newFrame)

            // If it still doesn't contain the cursor, move the window to be centered with the cursor
            if !newFrame.contains(currentMousePosition) {
                newFrame.origin.x = currentMousePosition.x - (newFrame.width / 2)
                await window.setFrame(newFrame)
            }
        }

        await WindowRecords.shared.eraseRecords(for: window)
    }

    private func processSnapAction() {
        guard let screen = NSScreen.screenWithMouse else {
            return
        }

        let mainScreen = NSScreen.screens[0]
        let screenFrame = screen.frame.flipY(screen: mainScreen)

        let inset = Defaults[.snapThreshold]
        let topInset = max(screen.menubarHeight / 2, inset)
        var ignoredFrame = screenFrame

        ignoredFrame.origin.x += inset
        ignoredFrame.size.width -= inset * 2
        ignoredFrame.origin.y += topInset
        ignoredFrame.size.height -= inset + topInset

        let oldDirection = resizeContext?.action.direction ?? .noAction

        if !ignoredFrame.contains(currentMousePosition) {
            let newDirection = WindowDirection.getSnapDirection(
                mouseLocation: currentMousePosition,
                currentDirection: oldDirection,
                screenFrame: screenFrame,
                ignoredFrame: ignoredFrame
            )

            // Only update if direction actually changed
            if newDirection != oldDirection {
                // Refresh accent colors in case user has enabled the wallpaper processor
                Task {
                    await AccentColorController.shared.refresh()
                }

                log.info("Window snapping direction changed: \(newDirection.debugDescription)")

                resizeContext?.setScreen(to: screen)
                resizeContext?.setAction(to: .init(newDirection), parent: nil)

                if let context = resizeContext {
                    previewController.open(context: context)
                }

                // Haptic feedback
                if newDirection != .noAction, Defaults[.hapticFeedback] {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
            }
        } else if !oldDirection.isNoOp {
            // Only close if we were showing something
            resizeContext?.setAction(to: .init(.noAction), parent: nil)
            previewController.close()
        }
    }
}
