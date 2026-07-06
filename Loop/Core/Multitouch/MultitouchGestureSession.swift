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
    private var lastCommitSwipeDistance: CGFloat = 0
    private var lastCommitMagnifyDistance: CGFloat = 0
    private var magnificationDirection: Int = 0

    func reset() {
        didOpenLoopWithThisGesture = false
        isGestureRejected = false
        hasActivated = false
        hasGestureBegun = false
        resolvedGesture = nil
        pendingTargetWindow = nil
        lastCommittedAction = nil
        lastCommitSwipeDistance = 0
        lastCommitMagnifyDistance = 0
        magnificationDirection = 0
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
    func commitSwipe(
        distance: CGFloat,
        newKey: ActionKey,
        step: CGFloat,
        fire: (_ reverse: Bool) -> ()
    ) {
        if lastCommittedAction == newKey {
            let delta = distance - lastCommitSwipeDistance
            if delta >= step {
                lastCommitSwipeDistance = distance
                fire(false)
            } else if delta <= -step {
                lastCommitSwipeDistance = distance
                fire(true)
            }
        } else {
            lastCommittedAction = newKey
            lastCommitSwipeDistance = distance
            fire(false)
        }
    }

    func commitRadialMagnify(
        distance: CGFloat,
        originDistance: CGFloat,
        step: CGFloat,
        fire: (_ reverse: Bool) -> ()
    ) {
        if lastCommittedAction != .radialCenter {
            lastCommittedAction = .radialCenter
            lastCommitMagnifyDistance = distance
            fire(distance < originDistance)
            return
        }

        let delta = distance - lastCommitMagnifyDistance
        if delta >= step {
            lastCommitMagnifyDistance = distance
            fire(false)
        } else if delta <= -step {
            lastCommitMagnifyDistance = distance
            fire(true)
        }
    }

    func commitMagnify(
        distance: CGFloat,
        originDistance: CGFloat,
        newKey: ActionKey,
        step: CGFloat,
        canRepeat: Bool,
        fire: (_ reverse: Bool) -> ()
    ) {
        if lastCommittedAction != newKey {
            magnificationDirection = distance >= originDistance ? 1 : -1
            lastCommittedAction = newKey
            lastCommitMagnifyDistance = distance
            fire(false)
            return
        }

        guard canRepeat else { return }

        let delta = (distance - lastCommitMagnifyDistance) * CGFloat(magnificationDirection)
        if delta >= step {
            lastCommitMagnifyDistance = distance
            fire(false)
        } else if delta <= -step {
            lastCommitMagnifyDistance = distance
            fire(true)
        }
    }

    func setResolvedGesture(_ gesture: GestureBinding) {
        resolvedGesture = gesture
    }

    func switchSwipeGesture(to gesture: GestureBinding, distance: CGFloat) {
        resolvedGesture = gesture
        lastCommittedAction = .gesture(gesture.id)
        lastCommitSwipeDistance = distance
    }

    func switchMagnifyGesture(to gesture: GestureBinding, distance: CGFloat, direction: Int) {
        resolvedGesture = gesture
        lastCommittedAction = .gesture(gesture.id)
        magnificationDirection = direction
        lastCommitMagnifyDistance = distance
    }

    func updateLastCommitSwipeDistance(_ distance: CGFloat) {
        lastCommitSwipeDistance = distance
    }

    func updateLastCommitMagnifyDistance(_ distance: CGFloat) {
        lastCommitMagnifyDistance = distance
    }
}
