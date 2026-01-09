//
//  StashedWindowStore.swift
//  Loop
//
//  Created by Guillaume Clédat on 28/05/2025.
//

import Defaults
import Foundation
import Scribe
import SwiftUI

protocol StashedWindowsStoreDelegate: AnyObject {
    func onStashedWindowsRestored()
}

/// Keep the stashed windows and the revealed window ids both in memory and in Defaults.
/// Restore windows stashed from a previous session.
final class StashedWindowsStore {
    weak var delegate: StashedWindowsStoreDelegate?

    private(set) var stashed: [CGWindowID: StashedWindowInfo] = [:]
    private(set) var revealed: Set<CGWindowID> = []

    /// Hold data from `Defaults[.stashManagerStashedWindows]` for windows that failed to be restored.
    private var failedToRestore: [CGWindowID: WindowAction] = [:]
    private var spaceObserver: NSObjectProtocol?

    // MARK: - Public methods

    func restore() {
        restoreStashedWindows()
    }

    func isWindowRevealed(_ id: CGWindowID) -> Bool {
        revealed.contains(id)
    }

    func markWindowAsRevealed(_ id: CGWindowID) {
        revealed.insert(id)
    }

    func markWindowAsHidden(_ id: CGWindowID) {
        revealed.remove(id)
    }

    /// Return the stashed window that match the given `action` and `screen`
    func stashedWindow(for action: WindowAction, on screen: NSScreen) -> StashedWindowInfo? {
        stashed.values.first { $0.action.id == action.id && $0.screen.isSameScreen(screen) }
    }

    func setStashedWindow(cgWindowID: CGWindowID, to window: StashedWindowInfo?) {
        guard stashed[cgWindowID] != window else {
            return
        }

        stashed[cgWindowID] = window

        Defaults[.stashManagerStashedWindows] = stashed.mapValues(\.action)
        Log.info("Persisted stashed windows (count: \(stashed.count))", category: .stashManager)
    }

    // MARK: Private methods

    private func restoreStashedWindows() {
        let windows = WindowUtility.windowList()
        let defaultStashedWindows = Defaults[.stashManagerStashedWindows]
        var restoredStashedWindows: [CGWindowID: StashedWindowInfo] = [:]

        for (windowId, direction) in defaultStashedWindows {
            guard let stashedWindow = getStashedWindow(for: windowId, in: windows, action: direction) else {
                failedToRestore[windowId] = direction
                continue
            }

            restoredStashedWindows[windowId] = stashedWindow
        }

        if !restoredStashedWindows.isEmpty {
            stashed = restoredStashedWindows
            Log.info("\(restoredStashedWindows.count) stashed window restored.", category: .stashedWindowsStore)
            delegate?.onStashedWindowsRestored()
        }

        if !failedToRestore.isEmpty {
            Log.error("Failed to restore \(failedToRestore.count) window(s).", category: .stashedWindowsStore)

            // Window restoration usually fail because the window is on another space and will
            // not be returned by WindowEngine.windowList until the user goes to that space.
            let notification = NSWorkspace.activeSpaceDidChangeNotification
            spaceObserver = NSWorkspace.shared.notificationCenter
                .addObserver(forName: notification, object: nil, queue: .main, using: onSpaceChanged)
        }
    }

    private func onSpaceChanged(_: Notification) {
        let windows = WindowUtility.windowList()
        var restored = 0

        Log.info("Space changed. Attempting to restore windows.", category: .stashedWindowsStore)

        for (windowId, direction) in failedToRestore {
            guard let stashedWindow = getStashedWindow(for: windowId, in: windows, action: direction) else {
                continue
            }

            stashed[windowId] = stashedWindow
            failedToRestore.removeValue(forKey: windowId)
            restored += 1
        }

        if restored > 0 {
            delegate?.onStashedWindowsRestored()
        }

        if let spaceObserver, failedToRestore.isEmpty {
            NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver)
        }
    }

    private func getStashedWindow(for windowId: CGWindowID, in windows: [Window], action: WindowAction) -> StashedWindowInfo? {
        guard let window = windows.first(where: { $0.cgWindowID == windowId }) else { return nil }
        guard let screen = ScreenUtility.screenContaining(window) ?? NSScreen.main else { return nil }

        return StashedWindowInfo(window: window, screen: screen, action: action)
    }
}
