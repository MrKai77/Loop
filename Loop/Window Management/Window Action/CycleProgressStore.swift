//
//  CycleProgressStore.swift
//  Loop
//
//  Created by Kai Azim on 2026-08-28.
//

import CoreGraphics
import Foundation

/// Tracks cycle progress by target window and parent cycle
struct CycleProgressStore {
    enum Direction {
        case forward
        case backward
    }

    struct Selection {
        let action: WindowAction
        let index: Int

        fileprivate let key: Key

        fileprivate init(action: WindowAction, index: Int, key: Key) {
            self.action = action
            self.index = index
            self.key = key
        }
    }

    fileprivate struct Key: Hashable {
        let targetWindowID: CGWindowID
        let parentCycleActionID: UUID
    }

    /// Keeps the selected occurrence when a cycle contains duplicate children
    private struct Cursor {
        let childActionID: UUID
        let lastKnownIndex: Int
    }

    private var cursors: [Key: Cursor] = [:]

    static func shouldRestartAtBeginning(
        whenEnabled isEnabled: Bool,
        currentAction: WindowAction,
        in children: [WindowAction]
    ) -> Bool {
        isEnabled && (
            currentAction.direction == .noSelection ||
                !children.contains { $0.id == currentAction.id }
        )
    }

    /// Returns the next child without updating progress.
    ///
    /// Restarts at the first child when requested. Otherwise, uses stored progress before `seedAction`.
    mutating func proposeSelection(
        for targetWindowID: CGWindowID,
        in cycleAction: WindowAction,
        seededBy seedAction: WindowAction?,
        restartAtBeginning: Bool,
        direction: Direction
    ) -> Selection? {
        let key = Key(
            targetWindowID: targetWindowID,
            parentCycleActionID: cycleAction.id
        )

        guard cycleAction.direction == .cycle,
              let children = cycleAction.cycle,
              !children.isEmpty
        else {
            cursors[key] = nil
            return nil
        }

        if restartAtBeginning {
            return Selection(action: children[0], index: 0, key: key)
        }

        if let cursor = cursors[key] {
            if let currentIndex = validatedIndex(for: cursor, in: children) {
                let index = nextIndex(after: currentIndex, count: children.count, direction: direction)
                return Selection(action: children[index], index: index, key: key)
            }

            // The selected child was removed, so re-seed from the updated cycle
            cursors[key] = nil
        }

        if let seedAction,
           let seedIndex = children.firstIndex(where: { $0.id == seedAction.id }) {
            let index = nextIndex(after: seedIndex, count: children.count, direction: direction)
            return Selection(action: children[index], index: index, key: key)
        }

        return Selection(action: children[0], index: 0, key: key)
    }

    /// Records a selection only if it still matches the current cycle
    @discardableResult
    mutating func accept(
        _ selection: Selection,
        for targetWindowID: CGWindowID,
        in cycleAction: WindowAction
    ) -> Bool {
        let key = Key(
            targetWindowID: targetWindowID,
            parentCycleActionID: cycleAction.id
        )

        guard key == selection.key else {
            return false
        }

        guard cycleAction.direction == .cycle,
              let children = cycleAction.cycle,
              !children.isEmpty
        else {
            cursors[key] = nil
            return false
        }

        let acceptedIndex: Int? = if children.indices.contains(selection.index),
                                     children[selection.index].id == selection.action.id {
            selection.index
        } else {
            children.firstIndex(where: { $0.id == selection.action.id })
        }

        guard let acceptedIndex else {
            cursors[key] = nil
            return false
        }

        cursors[key] = Cursor(
            childActionID: selection.action.id,
            lastKnownIndex: acceptedIndex
        )
        return true
    }

    mutating func reset(for targetWindowID: CGWindowID) {
        cursors = cursors.filter { $0.key.targetWindowID != targetWindowID }
    }

    mutating func reset() {
        cursors.removeAll()
    }

    private func validatedIndex(for cursor: Cursor, in children: [WindowAction]) -> Int? {
        if children.indices.contains(cursor.lastKnownIndex),
           children[cursor.lastKnownIndex].id == cursor.childActionID {
            return cursor.lastKnownIndex
        }

        return children.firstIndex(where: { $0.id == cursor.childActionID })
    }

    private func nextIndex(after index: Int, count: Int, direction: Direction) -> Int {
        switch direction {
        case .forward:
            (index + 1) % count
        case .backward:
            index == 0 ? count - 1 : index - 1
        }
    }
}
