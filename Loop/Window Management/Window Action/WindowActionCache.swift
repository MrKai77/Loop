//
//  WindowActionCache.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-11.
//

import AppKit
import Defaults
import OSLog

/// Caches the user's actions in a dictionary keyed by its keybind.
/// This is called from `KeybindObserver`, to retrieve the user's actions in an efficient manner.
final class WindowActionCache {
    private var actionsByKeybind: [Set<CGKeyCode>: WindowAction] = [:]
    private var observationTask: Task<(), Never>?
    private let logger = Logger(category: "WindowActionCache")

    /// Initializes a new instance of `WindowActionCache`.
    /// Will automatically build cache, and update according to changes the user makes to Loop's keybinds.
    init() {
        self.observationTask = Task { [weak self] in
            let updates = Defaults.updates(
                .keybinds,
                .cycleBackwardsOnShiftPressed
            )

            for await _ in updates {
                guard
                    !Task.isCancelled,
                    let self
                else {
                    break
                }

                regenerateCache()
            }
        }
    }

    subscript(_ keybind: Set<CGKeyCode>) -> WindowAction? {
        actionsByKeybind[keybind]
    }

    /// Rebuilds the cache and includes extra entries for cycle actions with shift keys if the user has enabled `cycleBackwardsOnShiftPressed`.
    private func regenerateCache() {
        let keybinds: [WindowAction] = Defaults[.keybinds].filter { !$0.keybind.isEmpty }
        let cycleBackwardsOnShiftPressed: Bool = Defaults[.cycleBackwardsOnShiftPressed]

        actionsByKeybind = Dictionary(
            keybinds.map { ($0.keybind, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        if cycleBackwardsOnShiftPressed {
            actionsByKeybind.merge(
                keybinds
                    .filter { $0.direction == .cycle }
                    .map { ($0.keybind.union([.kVK_Shift]), $0) },
                uniquingKeysWith: { first, _ in first }
            )
        }

        logger.info("Finished regenerating keybinds -> action dictionary")
    }
}
