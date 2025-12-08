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
    // Parameters
    private let windowActionCache: WindowActionCache
    private let changeAction: (WindowAction) -> ()
    private let selectNextCycleItem: () -> ()
    private let getInitialMousePosition: () -> CGPoint
    private let checkIfLoopOpen: () -> Bool

    private var mouseEventMonitor: PassiveEventMonitor?

    // State-keeping for previous calculations
    private var previousAngleToMouse: Angle = .zero
    private var previousDistanceToMouse: CGFloat = .zero

    private var radialMenuActions: [RadialMenuWindowAction] {
        Defaults[.radialMenuActions]
    }

    init(
        windowActionCache: WindowActionCache,
        changeAction: @escaping (WindowAction) -> (),
        selectNextCycleItem: @escaping () -> (),
        getInitialMousePosition: @escaping () -> CGPoint,
        checkIfLoopOpen: @escaping () -> Bool
    ) {
        self.windowActionCache = windowActionCache
        self.changeAction = changeAction
        self.selectNextCycleItem = selectNextCycleItem
        self.getInitialMousePosition = getInitialMousePosition
        self.checkIfLoopOpen = checkIfLoopOpen
    }

    @MainActor
    func start(initialMousePosition _: CGPoint) {
        mouseEventMonitor = PassiveEventMonitor(
            events: [
                .mouseMoved, // switch action when mouse is moved
                .otherMouseDragged, // switch action when mouse is moved with the middle mouse button clicked
                .leftMouseDown // Increment a cycle action on a left click
            ],
            callback: mouseEvent
        )

        // swiftformat:disable:next redundantSelf
        Log.info("Started with initial mouse position: \(self.getInitialMousePosition().debugDescription)", category: .mouseInteractionObserver)
    }

    @MainActor
    func stop() {
        mouseEventMonitor?.stop()
        mouseEventMonitor = nil

        previousAngleToMouse = .zero
        previousDistanceToMouse = .zero

        Log.success("Stopped, all stored states cleared.", category: .mouseInteractionObserver)
    }

    private func mouseEvent(_ event: CGEvent) {
        switch event.type {
        case .mouseMoved, .otherMouseDragged:
            processNewMouseLocation(event.location)
        case .leftMouseDown:
            activateNextCycleAction(event)
        default:
            break
        }
    }

    private func processNewMouseLocation(_: CGPoint) {
        guard checkIfLoopOpen() else { return }

        let noActionDistance: CGFloat = 10

        let initialMousePosition = getInitialMousePosition()
        let currentMousePosition = NSEvent.mouseLocation

        let angleToMouse = Angle(radians: initialMousePosition.angle(to: currentMousePosition))
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

        var newAction: RadialMenuWindowAction? = nil

        // If mouse over 50 points away, select half or quarter positions
        if distanceToMouse > 50 - Defaults[.radialMenuThickness] {
            guard radialMenuActions.count > 1 else {
                newAction = radialMenuActions.first
                return
            }

            let actions = Array(radialMenuActions[1...])
            let actionAngleSpan = 360.0 / CGFloat(actions.count)
            let halfAngleSpan = actionAngleSpan / 2.0
            let index = Int((angleToMouse.normalized().degrees + halfAngleSpan) / actionAngleSpan) % actions.count
            newAction = actions[index]
        } else if distanceToMouse > noActionDistance {
            newAction = radialMenuActions.first
        }

        Task { @MainActor in
            switch newAction {
            case let .custom(windowAction):
                changeAction(windowAction)
            case let .keybindReference(id):
                if let action = windowActionCache.actionsByIdentifier[id] { changeAction(action) }
            case nil:
                changeAction(.init(.noAction))
            }
        }
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
