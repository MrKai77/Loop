//
//  StashedWindowStore.swift
//  Loop
//
//  Created by Guillaume Clédat on 28/05/2025.
//

import Defaults
import Foundation
import SwiftUI

/// Keep the stashed windows and the revealed window ids both in memory and in Defaults.
class StashedWindowsStore {
    var stashed: [CGWindowID: StashedWindow] = [:] {
        didSet { persistStashedWindows() }
    }

    var revealed: Set<CGWindowID> = [] {
        didSet { persistRevealedWindows() }
    }

    private func persist() {
        persistRevealedWindows()
        persistStashedWindows()
    }

    func restore() {
        revealed = Defaults[.stashManagerRevealedWindows]

        for (windowId, direction) in Defaults[.stashManagerStashedWindows] {
            guard let window = WindowEngine.windowList.first(where: { $0.cgWindowID == windowId }) else {
                let windows = WindowEngine.windowList.map { "\($0.cgWindowID): \($0)" }

                print("Failed to restore stashed window with ID \(windowId): window not found.")
                print("Found windows: [\(windows)]")
                continue
            }

            guard let screen = ScreenManager.screenContaining(window) ?? NSScreen.main else {
                print("Failed to find screen for stashed window \(window)")
                continue
            }

            let bounds = WindowAction.getBounds(from: screen.safeScreenFrame, disablePadding: false, screen: screen)

            stashed[windowId] = StashedWindow(window: window, screenBounds: bounds, direction: direction)
            print("Restoring \(window) stashed on \(direction).")
        }
    }

    private func persistRevealedWindows() {
        Defaults[.stashManagerRevealedWindows] = revealed
    }

    private func persistStashedWindows() {
        Defaults[.stashManagerStashedWindows] = stashed.mapValues(\.direction)
    }
}
