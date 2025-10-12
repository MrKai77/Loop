//
//  WindowActionCache.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-11.
//

import AppKit
import AsyncAlgorithms
import Defaults
import OSLog

final class WindowActionCache {
    static let shared: WindowActionCache = .init()

    private var actionsByKeybind: [Set<CGKeyCode>: WindowAction] = [:]
    private var regenerationObserverTask: Task<(), Never>?
    private let logger = Logger(category: "WindowActionFetcher")

    private init() {
        regenerateCache()

        self.regenerationObserverTask = Task(priority: .background) {
            let keybindsStream = Defaults.updates(.keybinds)
            let cycleBackwardsOnShiftPressedStream = Defaults.updates(.cycleBackwardsOnShiftPressed)
            let combinedStream = zip(keybindsStream, cycleBackwardsOnShiftPressedStream)

            for await _ in combinedStream {
                regenerateCache()
            }
        }
    }

    subscript(_ keybind: Set<CGKeyCode>) -> WindowAction? {
        if actionsByKeybind.isEmpty {
            regenerateCache()
        }

        return actionsByKeybind[keybind]
    }

    private func regenerateCache() {
        let keybinds: [WindowAction] = Defaults[.keybinds].filter { !$0.keybind.isEmpty }
        let cycleBackwardsOnShiftPressed: Bool = Defaults[.cycleBackwardsOnShiftPressed]

        actionsByKeybind = Dictionary(
            keybinds.map { ($0.keybind, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        if cycleBackwardsOnShiftPressed {
            actionsByKeybind.merge(
                keybinds.map { ($0.keybind.union([.kVK_Shift]), $0) },
                uniquingKeysWith: { first, _ in first }
            )
        }

        logger.info("Finished regenerating keybinds -> action dictionary")
    }
}
