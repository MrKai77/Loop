//
//  MultitouchTrigger.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-30.
//

import Scribe
import Subsurface
import SwiftUI

@Loggable
final class MultitouchTrigger {
    private let windowActionCache: WindowActionCache
    private let openCallback: (WindowAction, Window) async throws -> ()
    private let closeCallback: (Bool) -> ()
    private let changeAction: (WindowAction, Bool) -> ()
    private let checkIfLoopOpen: () -> Bool

    private let gestureMonitor = SubsurfaceMonitor()
    private let gestureRecognizer = SubsurfaceGestureRecognizer(fingerCount: 2)
    private let gestureBlocker: MultitouchGestureBlocker = .init()

    private var didOpenLoopWithThisGesture = false
    private var isGestureRejected = false

    private var lastTriggeredActionIndex: Int?
    private var lastTriggeredDistance: CGFloat = 0

    private let panActivationThreshold: CGFloat = 0.3
    private let panCycleStepSize: CGFloat = 0.1
    private let pinchActivationThreshold: CGFloat = 0.4
    private let pinchCycleStepSize: CGFloat = 0.6

    private var radialMenuActions: [RadialMenuAction] {
        RadialMenuAction.userConfiguredActions
    }

    private static let failedToResolveKeybindAction: WindowAction = .init(.noAction)

    init(
        windowActionCache: WindowActionCache,
        openCallback: @escaping (WindowAction, Window) async throws -> (),
        closeCallback: @escaping (Bool) -> (),
        changeAction: @escaping (WindowAction, Bool) -> (),
        checkIfLoopOpen: @escaping () -> Bool
    ) {
        self.windowActionCache = windowActionCache
        self.openCallback = openCallback
        self.closeCallback = closeCallback
        self.changeAction = changeAction
        self.checkIfLoopOpen = checkIfLoopOpen
    }

    func start() {
        gestureMonitor.start()

        Task {
            for await event in gestureRecognizer.events(from: gestureMonitor) {
                switch event {
                case let .pan(pan):
                    await handlePan(pan)
                case let .pinch(pinch):
                    await handlePinch(pinch)
                case .rotation:
                    break
                }
            }
        }
    }

    func stop() {
        gestureMonitor.stop()
        gestureRecognizer.reset()
        resetLoopState()
    }

    private func handlePan(_ pan: SubsurfaceGestureEvent.PanEvent) async {
        switch pan.phase {
        case .began:
            await handleGestureBegan()

        case .changed:
            guard !isGestureRejected else { return }

            let angleFromOrigin = pan.angle + .pi / 2
            var normalizedAngle = angleFromOrigin
            if normalizedAngle < 0 { normalizedAngle += 2 * .pi }

            let actions = radialMenuActions.dropLast()
            guard actions.count > 1 else { return }

            let newIndex: Int
            if actions.count == 8 {
                newIndex = indexWithCardinalBias(angle: normalizedAngle, actionCount: actions.count)
            } else {
                let actionAngleSpan = (.pi * 2) / CGFloat(actions.count)
                let halfAngleSpan = actionAngleSpan / 2.0
                newIndex = Int((normalizedAngle + halfAngleSpan) / actionAngleSpan) % actions.count
            }

            // Determine if we're cycling the same action backward (pulling back)
            let isSameAction = lastTriggeredActionIndex == newIndex
            let isReversing = isSameAction && pan.distance < lastTriggeredDistance - panCycleStepSize

            if isSameAction {
                guard abs(pan.distance - lastTriggeredDistance) >= panCycleStepSize else { return }
            }

            lastTriggeredActionIndex = newIndex
            lastTriggeredDistance = pan.distance
            triggerAction(at: newIndex, from: actions, reverse: isReversing)

        case .ended, .cancelled:
            resetLoopState()

        default:
            break
        }
    }

    private func handlePinch(_ pinch: SubsurfaceGestureEvent.PinchEvent) async {
        switch pinch.phase {
        case .began:
            await handleGestureBegan()

        case .changed:
            guard !isGestureRejected else { return }

            let actions = radialMenuActions
            let centerActionIndex = actions.count - 1
            let isSameAction = lastTriggeredActionIndex == centerActionIndex
            let isReversing = isSameAction && pinch.scale < lastTriggeredDistance - pinchCycleStepSize

            if isSameAction {
                guard abs(pinch.scale - lastTriggeredDistance) >= pinchCycleStepSize else { return }
            } else {
                guard abs(pinch.scale - 1.0) >= pinchActivationThreshold else { return }
            }

            lastTriggeredActionIndex = centerActionIndex
            lastTriggeredDistance = pinch.scale
            triggerAction(at: centerActionIndex, from: actions[...], reverse: isReversing)

        case .ended, .cancelled:
            resetLoopState()

        default:
            break
        }
    }

    private func handleGestureBegan() async {
        let window = isCursorOverTitlebarOfWindow()
        let loopWasAlreadyOpen = checkIfLoopOpen()

        guard window != nil || loopWasAlreadyOpen else {
            isGestureRejected = true
            return
        }

        isGestureRejected = false
        lastTriggeredActionIndex = nil
        lastTriggeredDistance = 0
        gestureBlocker.start()

        if let window, !loopWasAlreadyOpen {
            do {
                try await openCallback(.init(.noSelection), window)
                didOpenLoopWithThisGesture = true
            } catch {
                gestureBlocker.stop()
                isGestureRejected = true
            }
        }
    }

    private func resetLoopState() {
        if didOpenLoopWithThisGesture {
            closeCallback(false)
        }

        gestureBlocker.stop()
        didOpenLoopWithThisGesture = false
        isGestureRejected = false
        lastTriggeredActionIndex = nil
        lastTriggeredDistance = 0
    }

    private func indexWithCardinalBias(angle: CGFloat, actionCount: Int, cardinalBias: CGFloat = 0.1) -> Int {
        let baseAngleSpan = (.pi * 2) / CGFloat(actionCount)
        let halfAngleSpan = baseAngleSpan / 2.0

        let adjustedAngle = (angle + halfAngleSpan).truncatingRemainder(dividingBy: .pi * 2)
        let rawSegment = Int(adjustedAngle / baseAngleSpan) % actionCount

        let segmentAngle = adjustedAngle.truncatingRemainder(dividingBy: baseAngleSpan)
        let normalizedPosition = segmentAngle / baseAngleSpan

        let isCurrentCardinal = rawSegment % 2 == 0

        if isCurrentCardinal {
            return rawSegment
        } else {
            if normalizedPosition < cardinalBias / 2 {
                return (rawSegment - 1 + actionCount) % actionCount
            } else if normalizedPosition > 1.0 - cardinalBias / 2 {
                return (rawSegment + 1) % actionCount
            } else {
                return rawSegment
            }
        }
    }

    private func isCursorOverTitlebarOfWindow() -> Window? {
        let cursorPosition = NSEvent.mouseLocation.flipY(screen: NSScreen.screens[0])

        guard let window = WindowUtility.windowAtPosition(cursorPosition) else {
            return nil
        }

        let titlebarHeight: CGFloat = 52.0

        let titlebarMinY = window.frame.minY
        let titlebarMaxY = window.frame.minY + titlebarHeight

        let isInTitlebar = cursorPosition.y >= titlebarMinY && cursorPosition.y <= titlebarMaxY

        return isInTitlebar ? window : nil
    }

    private func triggerAction(at index: Int, from actions: ArraySlice<RadialMenuAction>, reverse: Bool = false) {
        let action = actions[index]

        let resolvedAction: WindowAction = switch action.type {
        case let .custom(windowAction):
            windowAction
        case let .keybindReference(id):
            windowActionCache.actionsByIdentifier[id] ?? Self.failedToResolveKeybindAction
        }

        changeAction(resolvedAction, reverse)
    }
}
