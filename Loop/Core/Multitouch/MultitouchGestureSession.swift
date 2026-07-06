//
//  MultitouchGestureSession.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-30.
//

import SwiftUI

@MainActor
final class MultitouchGestureSession {
    enum ActionKey: Hashable {
        case radialSlot(Int)
        case radialCenter
        case gesture(UUID)
    }

    private(set) var didOpenLoopWithThisGesture = false
    private(set) var isGestureRejected = false
    private(set) var hasActivated = false
    private(set) var hasGestureBegun = false
    /// The gesture currently driving this stroke. Swapped on direction reversal
    private(set) var resolvedGesture: GestureBinding?
    private(set) var pendingTargetWindow: Window?

    private var lastCommittedAction: ActionKey?
    private var lastCommitPanDistance: CGFloat = 0
    private var lastCommitPinchDistance: CGFloat = 0
    private var pinchDirection: Int = 0

    func reset() {
        didOpenLoopWithThisGesture = false
        isGestureRejected = false
        hasActivated = false
        hasGestureBegun = false
        resolvedGesture = nil
        pendingTargetWindow = nil
        lastCommittedAction = nil
        lastCommitPanDistance = 0
        lastCommitPinchDistance = 0
        pinchDirection = 0
    }

    func begin(
        gesture _: GestureBinding,
        targetWindow: Window?,
        loopWasAlreadyOpen: Bool
    ) -> Bool {
        guard targetWindow != nil || loopWasAlreadyOpen else {
            reject()
            return false
        }

        reset()
        pendingTargetWindow = targetWindow
        hasGestureBegun = true
        // Loop is already on screen, so no activation threshold to cross.
        hasActivated = loopWasAlreadyOpen
        return true
    }

    func reject() {
        isGestureRejected = true
    }

    func markActivated(openedLoop: Bool) {
        if openedLoop {
            didOpenLoopWithThisGesture = true
        }
        hasActivated = true
    }

    /// Commit distance only advances when an action fires, so sub-step
    /// jitter can't drift it past the reverse threshold. Activation is gated
    /// upstream by `activateGestureIfNeeded`, so the first commit fires
    /// immediately to seed Loop's initial active action :)
    func commitPan(
        distance: CGFloat,
        newKey: ActionKey,
        step: CGFloat,
        fire: (_ reverse: Bool) -> ()
    ) {
        if lastCommittedAction == newKey {
            let delta = distance - lastCommitPanDistance
            if delta >= step {
                lastCommitPanDistance = distance
                fire(false)
            } else if delta <= -step {
                lastCommitPanDistance = distance
                fire(true)
            }
        } else {
            lastCommittedAction = newKey
            lastCommitPanDistance = distance
            fire(false)
        }
    }

    func commitRadialPinch(
        distance: CGFloat,
        originDistance: CGFloat,
        step: CGFloat,
        fire: (_ reverse: Bool) -> ()
    ) {
        if lastCommittedAction != .radialCenter {
            lastCommittedAction = .radialCenter
            lastCommitPinchDistance = distance
            fire(distance < originDistance)
            return
        }

        let delta = distance - lastCommitPinchDistance
        if delta >= step {
            lastCommitPinchDistance = distance
            fire(false)
        } else if delta <= -step {
            lastCommitPinchDistance = distance
            fire(true)
        }
    }

    func commitPinch(
        distance: CGFloat,
        originDistance: CGFloat,
        newKey: ActionKey,
        step: CGFloat,
        canRepeat: Bool,
        fire: (_ reverse: Bool) -> ()
    ) {
        if lastCommittedAction != newKey {
            pinchDirection = distance >= originDistance ? 1 : -1
            lastCommittedAction = newKey
            lastCommitPinchDistance = distance
            fire(false)
            return
        }

        guard canRepeat else { return }

        let delta = (distance - lastCommitPinchDistance) * CGFloat(pinchDirection)
        if delta >= step {
            lastCommitPinchDistance = distance
            fire(false)
        } else if delta <= -step {
            lastCommitPinchDistance = distance
            fire(true)
        }
    }

    func setResolvedGesture(_ gesture: GestureBinding) {
        resolvedGesture = gesture
    }

    func switchPanGesture(to gesture: GestureBinding, distance: CGFloat) {
        resolvedGesture = gesture
        lastCommittedAction = .gesture(gesture.id)
        lastCommitPanDistance = distance
    }

    func switchPinchGesture(to gesture: GestureBinding, distance: CGFloat, direction: Int) {
        resolvedGesture = gesture
        lastCommittedAction = .gesture(gesture.id)
        pinchDirection = direction
        lastCommitPinchDistance = distance
    }

    func updateLastCommitPanDistance(_ distance: CGFloat) {
        lastCommitPanDistance = distance
    }

    func updateLastCommitPinchDistance(_ distance: CGFloat) {
        lastCommitPinchDistance = distance
    }
}
