//
//  AltDragManager.swift
//  Loop
//
//  Created for Loop Fork.
//

import AppKit
import Defaults
import Scribe
import SwiftUI

@Loggable
@MainActor
final class AltDragManager {
    static let shared = AltDragManager()
    private init() {}

    private enum DragMode {
        case move
        case resize(AltDragAnchor)
    }

    private var isDragging: Bool = false
    private var dragMode: DragMode?
    private var targetWindow: Window?
    private var initialWindowFrame: CGRect = .zero
    private var initialMouseLocation: CGPoint = .zero

    private var eventMonitor: ActiveEventMonitor?
    private var accessibilityCheckerTask: Task<(), Never>?

    private var isEnabled: Bool {
        Defaults[.altDragEnabled]
    }

    func addObservers() {
        accessibilityCheckerTask = Task(priority: .background) { [weak self] in
            for await status in AccessibilityManager.shared.stream(initial: true) {
                guard let self, !Task.isCancelled else { return }
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
    }

    private func setupListeners() {
        removeListeners()

        let monitor = ActiveEventMonitor(
            "alt_drag_active_monitor",
            tapLocation: .cgSessionEventTap,
            placement: .headInsertEventTap,
            events: [
                .leftMouseDown,
                .leftMouseDragged,
                .leftMouseUp,
                .rightMouseDown,
                .rightMouseDragged,
                .rightMouseUp,
                .otherMouseDown,
                .otherMouseDragged,
                .otherMouseUp,
                .flagsChanged
            ],
            callback: { [weak self] event in
                guard let self else { return .forward }
                return self.handleEvent(event)
            }
        )

        monitor.start()
        self.eventMonitor = monitor
        log.info("AltDragManager event monitor started")
    }

    private func removeListeners() {
        eventMonitor?.stop()
        eventMonitor = nil
        log.info("AltDragManager event monitor stopped")
    }

    private func handleEvent(_ event: CGEvent) -> ActiveEventMonitor.EventHandling {
        guard isEnabled else { return .forward }

        let flags = event.flags
        let modifierMatches = Defaults[.altDragModifier].matches(flags: flags)
        let mouseLocation = event.location

        switch event.type {
        case .leftMouseDown:
            if modifierMatches {
                let isShiftPressed = flags.contains(.maskShift)
                if isShiftPressed && Defaults[.altDragResizeButton] == .shiftLeftClick {
                    return startDragging(mode: .resize(.bottomRight), at: mouseLocation)
                } else {
                    return startDragging(mode: .move, at: mouseLocation)
                }
            }

        case .rightMouseDown:
            if modifierMatches && Defaults[.altDragResizeButton] == .rightClick {
                return startDragging(mode: .resize(.bottomRight), at: mouseLocation)
            }

        case .otherMouseDown:
            if modifierMatches && Defaults[.altDragResizeButton] == .middleClick {
                return startDragging(mode: .resize(.bottomRight), at: mouseLocation)
            }

        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            if isDragging {
                updateDrag(currentLocation: mouseLocation)
                return .ignore
            }

        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            if isDragging {
                finishDragging()
                return .ignore
            }

        case .flagsChanged:
            break

        default:
            break
        }

        return .forward
    }

    private func startDragging(mode: DragMode, at point: CGPoint) -> ActiveEventMonitor.EventHandling {
        guard let window = WindowUtility.windowAtPosition(point), !window.isAppExcluded else {
            return .forward
        }

        self.targetWindow = window
        self.initialWindowFrame = window.frame
        self.initialMouseLocation = point

        if case .resize = mode {
            let anchor = AltDragAnchor.calculateAnchor(for: point, in: window.frame)
            self.dragMode = .resize(anchor)
        } else {
            self.dragMode = mode
        }

        self.isDragging = true
        log.info("Started Alt-Drag session on window: \(window.description), mode: \(String(describing: self.dragMode))")
        return .ignore
    }

    private func updateDrag(currentLocation: CGPoint) {
        guard isDragging,
              let window = targetWindow,
              let mode = dragMode,
              let screen = NSScreen.screenWithMouse ?? NSScreen.screens.first else {
            return
        }

        let deltaX = currentLocation.x - initialMouseLocation.x
        let deltaY = currentLocation.y - initialMouseLocation.y

        switch mode {
        case .move:
            var targetFrame = initialWindowFrame.offsetBy(dx: deltaX, dy: deltaY)
            targetFrame = SnappingEngine.snap(
                frame: targetFrame,
                on: screen,
                ignoreWindowID: window.cgWindowID
            )
            window.setFrame(targetFrame)
            StashManager.shared.onWindowManipulated(window.cgWindowID)

        case .resize(let anchor):
            var targetFrame = initialWindowFrame

            switch anchor {
            case .bottomRight: // Top-left was clicked, resize top and left
                let newX = initialWindowFrame.minX + deltaX
                let newY = initialWindowFrame.minY + deltaY
                let newW = max(150, initialWindowFrame.maxX - newX)
                let newH = max(100, initialWindowFrame.maxY - newY)
                targetFrame = CGRect(x: newX, y: newY, width: newW, height: newH)

            case .bottomLeft: // Top-right was clicked
                let newY = initialWindowFrame.minY + deltaY
                let newW = max(150, initialWindowFrame.width + deltaX)
                let newH = max(100, initialWindowFrame.maxY - newY)
                targetFrame = CGRect(x: initialWindowFrame.minX, y: newY, width: newW, height: newH)

            case .topRight: // Bottom-left was clicked
                let newX = initialWindowFrame.minX + deltaX
                let newW = max(150, initialWindowFrame.maxX - newX)
                let newH = max(100, initialWindowFrame.height + deltaY)
                targetFrame = CGRect(x: newX, y: initialWindowFrame.minY, width: newW, height: newH)

            case .topLeft, .center: // Bottom-right was clicked
                let newW = max(150, initialWindowFrame.width + deltaX)
                let newH = max(100, initialWindowFrame.height + deltaY)
                targetFrame = CGRect(origin: initialWindowFrame.origin, size: CGSize(width: newW, height: newH))
            }

            targetFrame = SnappingEngine.snapResize(
                frame: targetFrame,
                anchor: anchor,
                on: screen,
                ignoreWindowID: window.cgWindowID
            )
            window.setFrame(targetFrame)
            StashManager.shared.onWindowManipulated(window.cgWindowID)
        }
    }

    private func finishDragging() {
        guard isDragging else { return }

        if Defaults[.focusWindowOnResize] {
            targetWindow?.focus()
        }

        if let window = targetWindow {
            Task {
                await WindowRecords.shared.eraseRecords(for: window)
            }
        }

        log.info("Finished Alt-Drag session")
        resetDragState()
    }

    private func resetDragState() {
        isDragging = false
        dragMode = nil
        targetWindow = nil
        initialWindowFrame = .zero
        initialMouseLocation = .zero
    }
}
