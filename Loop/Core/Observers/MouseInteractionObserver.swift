//
//  MouseInteractionObserver.swift
//  Loop
//
//  Created by Kai Azim on 2025-11-11.
//

import Defaults
import Scribe
import SwiftUI

final class MouseInteractionObserver {
    private static let directionalActionDistance: CGFloat = 50
    private static let noActionDistance: CGFloat = 10

    // Parameters
    private let windowActionCache: WindowActionCache
    private let changeAction: (WindowAction) -> ()
    private let selectNextCycleItem: () -> ()
    private let checkIfLoopOpen: () -> Bool

    private var mouseEventMonitor: PassiveEventMonitor?

    // State-keeping for previous calculations
    private var previousAngleToMouse: Angle = .zero
    private var previousDistanceToMouse: CGFloat = .zero

    private var screenBounds: CGRect?
    private var shouldAccountForAbsoluteMousePosition: Bool = false
    private var initialMousePosition: CGPoint = .zero
    private var latestMousePosition: CGPoint = .zero

    private var radialMenuActions: [RadialMenuAction] {
        RadialMenuAction.userConfiguredActions
    }

    private static let failedToResolveKeybindAction: WindowAction = .init(.noAction) // This helps to keep a stable ID

    init(
        windowActionCache: WindowActionCache,
        changeAction: @escaping (WindowAction) -> (),
        selectNextCycleItem: @escaping () -> (),
        checkIfLoopOpen: @escaping () -> Bool
    ) {
        self.windowActionCache = windowActionCache
        self.changeAction = changeAction
        self.selectNextCycleItem = selectNextCycleItem
        self.checkIfLoopOpen = checkIfLoopOpen
    }

    func start(initialMousePosition: CGPoint) {
        screenBounds = NSScreen.screens.first(where: { $0.frame.contains(initialMousePosition) })?.frame

        if let screenBounds {
            /// If the current mouse position isn't sufficient for accessing direcitonal actions due to being close to the screen's edge, then enable `shouldAccountForAbsoluteMousePosition`
            let closeToMinX = abs(initialMousePosition.x - screenBounds.minX) < Self.directionalActionDistance
            let closeToMaxX = abs(initialMousePosition.x - screenBounds.maxX) < Self.directionalActionDistance
            let closeToMinY = abs(initialMousePosition.y - screenBounds.minY) < Self.directionalActionDistance
            let closeToMaxY = abs(initialMousePosition.y - screenBounds.maxY) < Self.directionalActionDistance

            if closeToMinX || closeToMaxX || closeToMinY || closeToMaxY {
                shouldAccountForAbsoluteMousePosition = true
            }
        }

        self.initialMousePosition = initialMousePosition
        latestMousePosition = initialMousePosition

        mouseEventMonitor = PassiveEventMonitor(
            events: [
                .mouseMoved, // switch action when mouse is moved
                .otherMouseDragged, // switch action when mouse is moved with the middle mouse button clicked
                .leftMouseDown // Increment a cycle action on a left click
            ],
            callback: mouseEvent
        )

        Log.info("Started with initial mouse position: \(latestMousePosition.debugDescription)", category: .mouseInteractionObserver)
    }

    func stop() {
        mouseEventMonitor?.stop()
        mouseEventMonitor = nil

        previousAngleToMouse = .zero
        previousDistanceToMouse = .zero

        screenBounds = nil
        shouldAccountForAbsoluteMousePosition = false
        initialMousePosition = .zero
        latestMousePosition = .zero

        Log.success("Stopped, all stored states cleared.", category: .mouseInteractionObserver)
    }

    private func mouseEvent(_ event: CGEvent) {
        switch event.type {
        case .mouseMoved, .otherMouseDragged:
            processNewMouseLocation(event)
        case .leftMouseDown:
            activateNextCycleAction(event)
        default:
            break
        }
    }

    private func processNewMouseLocation(_ event: CGEvent) {
        guard checkIfLoopOpen() else { return }

        let currentMousePosition = computeLatestMousePosition(event)
        let angleToMouse = initialMousePosition.angle(to: currentMousePosition) + .radians(.pi / 2)
        let distanceToMouse = initialMousePosition.distance(to: currentMousePosition)

        // Return if the mouse didn't move
        guard
            angleToMouse != previousAngleToMouse ||
            distanceToMouse != previousDistanceToMouse
        else {
            return
        }

        // Get angle & distance to mouse
        previousAngleToMouse = angleToMouse
        previousDistanceToMouse = distanceToMouse

        var newAction: RadialMenuAction? = nil

        // If mouse over 50 points away, select half or quarter positions
        if distanceToMouse > Self.directionalActionDistance - Defaults[.radialMenuThickness] {
            guard radialMenuActions.count > 1 else {
                newAction = radialMenuActions.first
                return
            }

            let actions = radialMenuActions.dropLast()
            let actionAngleSpan = 360.0 / CGFloat(actions.count)
            let halfAngleSpan = actionAngleSpan / 2.0
            let index = Int((angleToMouse.normalized().degrees + halfAngleSpan) / actionAngleSpan) % actions.count
            newAction = actions[index]
        } else if distanceToMouse > Self.noActionDistance {
            newAction = radialMenuActions.last
        }

        Task { @MainActor in
            switch newAction?.type {
            case let .custom(windowAction):
                changeAction(windowAction)
            case let .keybindReference(id):
                if let action = windowActionCache.actionsByIdentifier[id] {
                    changeAction(action)
                } else {
                    changeAction(Self.failedToResolveKeybindAction)
                }
            case nil:
                changeAction(.init(.noSelection))
            }
        }
    }

    /// Computes a resolved mouse position, compensating for macOS cursor clamping at screen edges.
    ///
    /// When enabled, this method continues tracking movement along an axis even after the system
    /// cursor becomes pinned to a screen edge by applying the event’s delta to the last known position,
    /// while clamping the result to a limited distance from the edge, just enough to access directional actions.
    ///
    /// - Parameter event: the CGEvent associated with this mouse movement
    /// - Returns: the computed absolute mouse position
    private func computeLatestMousePosition(_ event: CGEvent) -> CGPoint {
        let current = NSEvent.mouseLocation

        guard shouldAccountForAbsoluteMousePosition, let bounds = screenBounds else {
            latestMousePosition = current
            return latestMousePosition
        }

        let edgeThreshold: CGFloat = 1
        let deltaX = event.getDoubleValueField(.mouseEventDeltaX)
        let deltaY = event.getDoubleValueField(.mouseEventDeltaY)
        let maxOffset = Self.directionalActionDistance

        let atMinX = abs(current.x - bounds.minX) < edgeThreshold
        let atMaxX = abs(current.x - bounds.maxX) < edgeThreshold
        let atMinY = abs(current.y - bounds.minY) < edgeThreshold
        let atMaxY = abs(current.y - bounds.maxY) < edgeThreshold

        var resolved = current

        if atMinX || atMaxX {
            let unclampedX = latestMousePosition.x + deltaX
            let minX = bounds.minX - maxOffset
            let maxX = bounds.maxX + maxOffset

            resolved.x = min(max(unclampedX, minX), maxX)

        } else if atMinY || atMaxY {
            let unclampedY = latestMousePosition.y + deltaY
            let minY = bounds.minY - maxOffset
            let maxY = bounds.maxY + maxOffset

            resolved.y = min(max(unclampedY, minY), maxY)
        }

        latestMousePosition = resolved
        return resolved
    }

    private func activateNextCycleAction(_ event: CGEvent) {
        /// Ensure that the source originates from the HID state ID.
        /// Otherwise, this event was likely sent from Loop to focus the frontmost click (see `Window.focus` which sends a `SLSEvent` to the window)
        let sourceID = CGEventSourceStateID(rawValue: Int32(event.getIntegerValueField(.eventSourceStateID)))
        guard sourceID == .hidSystemState else {
            return
        }

        Task { @MainActor in
            guard checkIfLoopOpen() else {
                return
            }

            selectNextCycleItem()
        }
    }
}
