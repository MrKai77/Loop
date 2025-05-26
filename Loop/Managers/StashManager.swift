//
//  StashManager.swift
//  Loop
//
//  Created by Guillaume Clédat on 22/05/2025.
//

import Defaults
import SwiftUI

enum StashDirection {
    case left, right
}

struct StashedWindow {
    let window: Window
    let screen: NSScreen
    let direction: StashDirection
    let revealFrame: CGRect
    let stashedFrame: CGRect
}

class StashManager {
    /// Should the stashed windows be animated when revealed or hidden?
    private var animate: Bool {
        Defaults[.animateStashedWindows]
    }

    // TODO: Store this in Defaults
    /// How many pixels of the window should be visible when stashed
    private let stashedWindowPadding: CGFloat = 20

    private var stashedWindows: [CGWindowID: StashedWindow] = [:]
    private var revealedWindows: Set<CGWindowID> = []
    private var mouseMonitor: NSEventMonitor?
}

// MARK: - Public methods

extension StashManager {
    /// Handles stash or unstash actions for the given window.
    /// - Returns: `true` if the window was stashed or unstashed, `false` otherwise.
    @discardableResult
    func handle(window: Window, on screen: NSScreen, action: WindowAction) -> Bool {
        if [.stashLeft, .stashRight].contains(action.direction) {
            stash(window: window, on: screen, action: action)
            return true
        } else if [.unstashAll, .unstash].contains(action.direction) {
            unstash(window: window, action: action)
            return true
        } else {
            // The window will be moved or resized by another command so it won't be stashed anymore:
            stashedWindows.removeValue(forKey: window.cgWindowID)
            return false
        }
    }
}

// MARK: - Stash and Unstash

private extension StashManager {
    /// Stashes the given window in the direction specified by `action`.
    private func stash(window: Window, on screen: NSScreen, action: WindowAction) {
        let windowID = window.cgWindowID
        let currentFrame = window.frame
        var revealFrame = currentFrame
        var stashedFrame = currentFrame
        var direction: StashDirection

        if action.direction == .stashRight {
            revealFrame.origin.x = screen.frame.maxX - revealFrame.width - Defaults[.padding].right
            stashedFrame.origin.x = screen.frame.maxX - stashedWindowPadding
            direction = .right
        } else if action.direction == .stashLeft {
            revealFrame.origin.x = screen.frame.minX + Defaults[.padding].left
            stashedFrame.origin.x = screen.frame.minX - stashedFrame.width + stashedWindowPadding
            direction = .left
        } else {
            return
        }

        let stashedWindow = StashedWindow(
            window: window,
            screen: screen,
            direction: direction,
            revealFrame: revealFrame,
            stashedFrame: stashedFrame
        )

        stashedWindows[windowID] = stashedWindow
        hideWindow(stashedWindow, animate: animate)
        startListeningMouseMoved()
    }

    /// Handle the `.unstash` or `.unstashAll` action for the given window.
    private func unstash(window: Window, action: WindowAction) {
        if action.direction == .unstash {
            unstash(windowID: window.cgWindowID)
        } else if action.direction == .unstashAll {
            stashedWindows.keys.forEach(unstash(windowID:))
        }

        if stashedWindows.isEmpty {
            stopListeningMouseMoved()
        }
    }

    /// Unstashes a specific window by its ID.
    private func unstash(windowID: CGWindowID) {
        guard let stashedWindow = stashedWindows[windowID] else { return }

        revealWindow(stashedWindow, animate: false)

        revealedWindows.remove(windowID)
        stashedWindows.removeValue(forKey: windowID)
    }
}

// MARK: - Reveal and Hide

private extension StashManager {
    /// Reveals a stashed window by moving it to its reveal frame.
    private func revealWindow(_ window: StashedWindow, animate: Bool) {
        let windowID = window.window.cgWindowID

        guard !revealedWindows.contains(windowID) else { return }

        window.window.activate()
        window.window.setFrame(window.revealFrame, animate: animate)
        revealedWindows.insert(windowID)
    }

    /// Hides a stashed window by moving it to its stashed frame.
    private func hideWindow(_ window: StashedWindow, animate: Bool) {
        let windowID = window.window.cgWindowID

        // current `unfocus` implementation is doing more bad than good atm.
        // unfocus(windowID)
        window.window.setFrame(window.stashedFrame, animate: animate)
        revealedWindows.remove(windowID)
    }

    // TODO: unfocus should only focus window in the same (virtual) space.

    /// Unfocuses a window by attempting to focus another window on the same screen.
    func unfocus(_ windowID: CGWindowID) {
        guard let stashedWindow = stashedWindows[windowID] else { return }
        guard let screen = ScreenManager.screenContaining(stashedWindow.window) ?? NSScreen.main else { return }

        let focusWindow = WindowEngine.windowList.first(where: { window in
            guard let currentWindowScreen = ScreenManager.screenContaining(window) ?? NSScreen.main else { return false }
            guard screen.isSameScreen(currentWindowScreen) else { return false }

            return window.cgWindowID != windowID && !window.isHidden && !window.minimized
        })

        if let focusWindow {
            if let id = focusWindow.nsRunningApplication?.bundleIdentifier {
                print("Focusing another window on the same screen: \(id)")
            }
            focusWindow.activate()
        }
    }
}

// MARK: - Mouse moved listener

private extension StashManager {
    private func startListeningMouseMoved() {
        print("Listening for mouse moved events…")

        mouseMonitor = NSEventMonitor(scope: .global, eventMask: .mouseMoved) { [weak self] _ in
            self?.handleMouseMoved()
            return nil
        }
        mouseMonitor?.start()
    }

    private func stopListeningMouseMoved() {
        print("Stopping listening for mouse moved events…")

        mouseMonitor?.stop()
        mouseMonitor = nil
    }

    /// Handles mouse movement events to reveal or hide stashed windows.
    private func handleMouseMoved() {
        for (windowID, window) in stashedWindows {
            let mouseLocation = NSEvent.mouseLocation.flipY(screen: NSScreen.screens[0])
            let isWindowRevealed = revealedWindows.contains(windowID)
            let isMouseOverStashedWindow = window.stashedFrame.contains(mouseLocation)
            let isMouseOverRevealFrame = window.revealFrame.contains(mouseLocation)

            if isWindowRevealed, !isMouseOverRevealFrame, !isMouseOverStashedWindow {
                hideWindow(window, animate: animate)
            } else if isMouseOverStashedWindow {
                revealWindow(window, animate: animate)
            }
        }
    }
}
