//
//  MouseInteractionObserver.swift
//  Loop
//
//  Created by Kai Azim on 2025-11-11.
//

import Defaults
import OSLog
import SwiftUI

final class MouseInteractionObserver {
    private let logger = Logger(category: "MouseInteractionObserver")

    // Callbacks
    private let changeAction: (WindowAction) -> ()
    private let selectNextCycleItem: () -> ()
    private let getInitialMousePosition: () -> CGPoint
    private let checkIfLoopOpen: () -> Bool

    private var mouseEventMonitor: PassiveEventMonitor?

    // State-keeping for previous calculations
    private var previousAngleToMouse: Angle = .zero
    private var previousDistanceToMouse: CGFloat = .zero

    init(
        changeAction: @escaping (WindowAction) -> (),
        selectNextCycleItem: @escaping () -> (),
        getInitialMousePosition: @escaping () -> CGPoint,
        checkIfLoopOpen: @escaping () -> Bool
    ) {
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
        logger.info("Started with initial mouse position: \(self.getInitialMousePosition().debugDescription)")
    }

    @MainActor
    func stop() {
        mouseEventMonitor?.stop()
        mouseEventMonitor = nil

        previousAngleToMouse = .zero
        previousDistanceToMouse = .zero

        logger.info("Stopped, all stored states cleared.")
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
        Task { @MainActor in
            guard checkIfLoopOpen() else { return }

            let noActionDistance: CGFloat = 10

            let initialMousePosition = getInitialMousePosition()
            let currentMousePosition = NSEvent.mouseLocation

            let angleToMouse = Angle(radians: initialMousePosition.angle(to: currentMousePosition))
            let distanceToMouse = initialMousePosition.distance(to: currentMousePosition)

            // Return if the mouse didn't move
            guard
                angleToMouse != previousAngleToMouse,
                distanceToMouse != previousDistanceToMouse
            else {
                return
            }

            // Get angle & distance to mouse
            previousAngleToMouse = angleToMouse
            previousDistanceToMouse = distanceToMouse

            var newAction: WindowAction = .init(.noAction)

            // If mouse over 50 points away, select half or quarter positions
            if distanceToMouse > 50 - Defaults[.radialMenuThickness] {
                switch Int((angleToMouse.normalized().degrees + 22.5) / 45) {
                case 0, 8: newAction = Defaults[.radialMenuRight]
                case 1: newAction = Defaults[.radialMenuBottomRight]
                case 2: newAction = Defaults[.radialMenuBottom]
                case 3: newAction = Defaults[.radialMenuBottomLeft]
                case 4: newAction = Defaults[.radialMenuLeft]
                case 5: newAction = Defaults[.radialMenuTopLeft]
                case 6: newAction = Defaults[.radialMenuTop]
                case 7: newAction = Defaults[.radialMenuTopRight]
                default: break
                }
            } else if distanceToMouse > noActionDistance {
                newAction = Defaults[.radialMenuCenter]
            }

            changeAction(newAction)
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
