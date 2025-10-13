//
//  StashedWindowStore.swift
//  Loop
//
//  Created by Guillaume Clédat on 28/05/2025.
//

import Defaults
import Foundation
import OSLog
import SwiftUI

protocol StashedWindowsStoreDelegate: AnyObject {
    func onStashedWindowsRestored()
}

/// Keep the stashed windows and the revealed window ids both in memory and in Defaults.
/// Restore windows stashed from a previous session.
final class StashedWindowsStore {
    weak var delegate: StashedWindowsStoreDelegate?

    private let logger = Logger(category: "StashedWindowsStore")

    var stashed: [CGWindowID: StashedWindow] = [:] {
        didSet { persistStashedWindows() }
    }

    var revealed: Set<CGWindowID> = [] {
        didSet { persistRevealedWindows() }
    }

    /// Hold data from `Defaults[.stashManagerStashedWindows]` for windows that failed to be restored.
    private var failedToRestore: [CGWindowID: WindowAction] = [:]
    private var spaceObserver: NSObjectProtocol?

    // MARK: - Public methods

    func restore() {
        restoreRevealedWindows()
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
    func stashedWindow(for action: WindowAction, on screen: NSScreen) -> StashedWindow? {
        for stashedWindow in stashed.values {
            if stashedWindow.action.isSameManipulation(as: action), stashedWindow.screen.isSameScreen(screen) {
                return stashedWindow
            }
        }
        return nil
    }

    // MARK: Private methods

    func restoreRevealedWindows() {
        revealed = Defaults[.stashManagerRevealedWindows]
    }

    func restoreStashedWindows() {
        let windows = WindowUtility.windowList()
        let defaultStashedWindows = Defaults[.stashManagerStashedWindows]
        var restoredStashedWindows: [CGWindowID: StashedWindow] = [:]

        for (windowId, direction) in defaultStashedWindows {
            guard let stashedWindow = getStashedWindow(for: windowId, in: windows, action: direction) else {
                failedToRestore[windowId] = direction
                continue
            }

            restoredStashedWindows[windowId] = stashedWindow
        }

        if !restoredStashedWindows.isEmpty {
            stashed = restoredStashedWindows
            logger.info("\(restoredStashedWindows.count) stashed window restored.")
            delegate?.onStashedWindowsRestored()
        }

        if !failedToRestore.isEmpty {
            // swiftformat:disable:next redundantSelf
            logger.error("Failed to restore \(self.failedToRestore.count) window(s).")

            // Window restoration usually fail because the window is on another space and will
            // not be returned by WindowEngine.windowList until the user goes to that space.
            let notification = NSWorkspace.activeSpaceDidChangeNotification
            spaceObserver = NSWorkspace.shared.notificationCenter
                .addObserver(forName: notification, object: nil, queue: .main, using: onSpaceChanged)
        }
    }

    func onSpaceChanged(_: Notification) {
        let windows = WindowUtility.windowList()
        var restored = 0

        logger.info("Space changed. Attempting to restore windows.")

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

    func getStashedWindow(for windowId: CGWindowID, in windows: [Window], action: WindowAction) -> StashedWindow? {
        guard let window = windows.first(where: { $0.cgWindowID == windowId }) else { return nil }
        guard let screen = ScreenUtility.screenContaining(window) ?? NSScreen.main else { return nil }

        return StashedWindow(window: window, screen: screen, action: action)
    }

    func persistRevealedWindows() {
        Defaults[.stashManagerRevealedWindows] = revealed
    }

    func persistStashedWindows() {
        Defaults[.stashManagerStashedWindows] = stashed.mapValues(\.action)
    }
}
