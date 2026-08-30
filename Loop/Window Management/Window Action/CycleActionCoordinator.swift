//
//  CycleActionCoordinator.swift
//  Loop
//
//  Created by Kai Azim on 2026-08-30.
//

import CoreGraphics

struct CycleActionCoordinator {
    struct Proposal {
        let action: WindowAction

        fileprivate let selection: CycleProgressStore.Selection
    }

    private var progressStore = CycleProgressStore()
    private var keybindSequenceOriginAction: WindowAction?

    mutating func proposeAction(
        for targetWindowID: CGWindowID,
        in cycleAction: WindowAction,
        currentAction: WindowAction,
        currentParentAction: WindowAction?,
        recordedAction: WindowAction?,
        restartAtBeginningWhenInterrupted: Bool,
        direction: CycleProgressStore.Direction
    ) -> Proposal? {
        let currentActionBelongsToCycle = cycleAction.cycle?.contains {
            $0.id == currentAction.id
        } == true
        let restartAtBeginning = Self.shouldRestartAtBeginning(
            whenEnabled: restartAtBeginningWhenInterrupted,
            currentAction: currentAction,
            currentParentAction: currentParentAction,
            keybindSequenceOriginAction: keybindSequenceOriginAction,
            in: cycleAction
        )
        let seedAction: WindowAction? = if restartAtBeginning {
            nil
        } else if currentActionBelongsToCycle {
            currentAction
        } else {
            recordedAction
        }

        guard let selection = progressStore.proposeSelection(
            for: targetWindowID,
            in: cycleAction,
            seededBy: seedAction,
            restartAtBeginning: restartAtBeginning,
            direction: direction
        ) else {
            return nil
        }

        return Proposal(action: selection.action, selection: selection)
    }

    mutating func commit(
        _ proposal: Proposal,
        for targetWindowID: CGWindowID,
        in cycleAction: WindowAction
    ) -> WindowAction? {
        progressStore.commit(
            proposal.selection,
            for: targetWindowID,
            in: cycleAction
        )
    }

    mutating func recordActionTransition(
        from currentAction: WindowAction,
        currentParentAction: WindowAction?,
        to newAction: WindowAction,
        newParentAction: WindowAction?
    ) {
        let currentBindingAction = currentParentAction ?? currentAction
        let nextBindingAction = newParentAction ?? newAction
        let continuesKeybindSequence = !currentBindingAction.keybind.isEmpty
            && currentBindingAction.keybind.isStrictSubset(of: nextBindingAction.keybind)

        if !continuesKeybindSequence {
            keybindSequenceOriginAction = currentBindingAction
        }
    }

    mutating func resetProgress(for targetWindowID: CGWindowID) {
        progressStore.reset(for: targetWindowID)
    }

    mutating func resetProgress() {
        progressStore.reset()
    }

    static func shouldRestartAtBeginning(
        whenEnabled isEnabled: Bool,
        currentAction: WindowAction,
        currentParentAction: WindowAction?,
        keybindSequenceOriginAction: WindowAction?,
        in cycleAction: WindowAction
    ) -> Bool {
        let currentKeybind = currentParentAction?.keybind ?? currentAction.keybind
        let isRepeatingLongerKeybind = keybindSequenceOriginAction?.id == cycleAction.id
            && !currentKeybind.isEmpty
            && currentKeybind.isStrictSubset(of: cycleAction.keybind)

        return isEnabled && (
            !isRepeatingLongerKeybind && (
                currentAction.direction == .noSelection ||
                    cycleAction.cycle?.contains { $0.id == currentAction.id } != true
            )
        )
    }
}
