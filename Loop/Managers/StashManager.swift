//
//  StashManager.swift
//  Loop
//
//  Created by Guillaume Clédat on 22/05/2025.
//

import Defaults
import SwiftUI

enum StashDirection {
    case left(StashRegion)
    case right(StashRegion)
}

/// Represents the vertical region along the screen’s edges where a window can be stashed.
///
/// This region determines how the window is positioned along the y-axis.
/// Some regions also modify the window's height, while its width remains unchanged.
///
/// - Note:
///   Currently, no regions modify the window’s width to keep the number of cases manageable.
///   By first applying one of the available `WindowDirection` options to set the window’s size,
///   and then stashing it in a `StashRegion`, the user can achieve a variety of stashed window sizes.
///
///   While it would be possible to add more `StashRegion` cases—such as ones modifying both height and width—
///   this would require creating a `WindowDirection` for each possible combination of `StashDirection` and `StashRegion`.
enum StashRegion {
    /// The top edge of the screen. The window retains its original size.
    case top
    /// The bottom edge of the screen. The window retains its original size.
    case bottom
    /// Vertically centered along the screen edge. The window retains its original size.
    case center
    /// The entire height of the screen edge. The window height is adjusted to fill the screen.
    case full
    /// The top half of the screen. The window height is adjusted to half the screen height.
    case topHalf
    /// The bottom half of the screen. The window height is adjusted to half the screen height.
    case bottomHalf
}

struct StashedWindow {
    let window: Window
    let screenBounds: CGRect
    let direction: StashDirection
}

class StashManager {
    /// Should the stashed windows be animated when revealed or hidden?
    private var animate: Bool {
        Defaults[.animateStashedWindows]
    }

    /// How many pixels of the window should be visible when stashed
    private var stashedWindowVisiblePadding: CGFloat {
        Defaults[.stashedWindowVisiblePadding]
    }

    private var padding: PaddingModel {
        Defaults[.padding]
    }

    /// The time interval to debounce mouse moved events to avoid excessive processing.
    private let mouseMovedDebounceInterval: TimeInterval = 0.05

    /// The throttle interval for revealing/hiding windows when the mouse moves.
    private let revealThrottleInterval: TimeInterval = 0.1

    private var stashedWindows: [CGWindowID: StashedWindow] = [:]
    private var revealedWindows: Set<CGWindowID> = []
    private var lastRevealTime: [CGWindowID: Date] = [:]
    private var mouseMonitor: NSEventMonitor?
    private var mouseMoveWorkItem: DispatchWorkItem?

    init() {
        Notification.Name.UIDirectionUpdated.onReceive { [weak self] obj in
            guard let action = obj.userInfo?["action"] as? WindowAction else { return }
            guard let window = obj.userInfo?["window"] as? Window else { return }
            guard let screen = obj.userInfo?["screen"] as? NSScreen else { return }

            self?.onUIDirectionUpdated(action: action, window: window, screen: screen)
        }
    }

    deinit {
        mouseMoveWorkItem?.cancel()
        stopListeningMouseMoved()
    }
}

// MARK: - Stash and Unstash

private extension StashManager {
    /// Handles `UIDirectionUpdated` notification for the specified window and action.
    ///
    /// If the action corresponds to a stash direction, the window is hidden in the stash area and monitored.
    /// If the action corresponds to an unstash, the window is moved out of the stash area and monitoring is stopped.
    /// Other actions (e.g., resizing or moving) will cancel the stashed state so monitoring is stopped.
    func onUIDirectionUpdated(action: WindowAction, window: Window, screen: NSScreen) {
        if let direction = StashDirection(direction: action.direction) {
            let bounds = WindowAction.getBounds(from: screen.safeScreenFrame, disablePadding: false, screen: screen)
            let windowToStash = StashedWindow(window: window, screenBounds: bounds, direction: direction)

            stash(windowToStash)
        } else if action.direction == .unstash {
            unstash(window.cgWindowID)
        } else if action.direction == .unstashAll {
            unstashAll()
        } else if action.direction == .undo {
            // TODO: If the previous action was not a stack action we should unmanage the window.
        } else {
            // TODO: Handle .smaller, .bigger, .shrink, .grow, .move
            // The window will be moved or resized by another command so it won't be stashed anymore:
            unmanage(windowID: window.cgWindowID)
        }
    }

    /// Add the given `StashWindow` to the list of monitored windows, move the window to the stashed area
    /// and start mouse moved listener if needed.
    func stash(_ windowToStash: StashedWindow) {
        // TODO: Handle window overlap
        stashedWindows[windowToStash.window.cgWindowID] = windowToStash
        hideWindow(windowToStash, animate: animate)
        startListeningMouseMoved()
    }

    /// Stop monitoring all the monitored windows.
    func unstashAll() {
        stashedWindows.keys.forEach(unstash)
    }

    /// Stop monitoring the window with the given `CGWindowID`.
    func unstash(_ windowID: CGWindowID) {
        unmanage(windowID: windowID)
    }
}

// MARK: - Reveal and Hide

private extension StashManager {
    /// Reveals a stashed window by moving it to its reveal frame.
    func revealWindow(_ window: StashedWindow, animate: Bool) {
        let windowID = window.window.cgWindowID

        guard !revealedWindows.contains(windowID) else { return }
        guard !shouldThrottle(windowID: windowID) else { return }

        let frame = window.computeRevealedFrame()

        // TODO: Apply padding

        window.window.activate()
        revealedWindows.insert(windowID)
        window.window.setFrame(frame, animate: animate)
    }

    /// Hides a stashed window by moving it to its stashed frame.
    func hideWindow(_ window: StashedWindow, animate: Bool) {
        let windowID = window.window.cgWindowID

        guard !shouldThrottle(windowID: windowID) else { return }

        let frame = window.computeStashedFrame(peekSize: stashedWindowVisiblePadding)

        // current `unfocus` implementation is doing more bad than good atm.
        // unfocus(windowID)
        window.window.setFrame(frame, animate: animate)
        revealedWindows.remove(windowID)
    }

    /// Checks if the window reveal / hide should be throttled based on the last reveal time.
    func shouldThrottle(windowID: CGWindowID) -> Bool {
        let now = Date.now
        if let lastTime = lastRevealTime[windowID], now.timeIntervalSince(lastTime) < revealThrottleInterval {
            return true
        }
        lastRevealTime[windowID] = now
        return false
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
                print("StashManager: Focusing another window on the same screen: \(id).")
            }
            focusWindow.activate()
        }
    }
}

// MARK: - Mouse moved listener

private extension StashManager {
    func startListeningMouseMoved() {
        guard mouseMonitor == nil else { return }

        print("StashManager: Listening for mouse moved events…")

        mouseMonitor = NSEventMonitor(scope: .global, eventMask: .mouseMoved) { [weak self] _ in
            self?.handleMouseMoved()
            return nil
        }
        mouseMonitor?.start()
    }

    func stopListeningMouseMoved() {
        guard mouseMonitor != nil else { return }

        print("StashManager: Stopping listening for mouse moved events…")

        mouseMonitor?.stop()
        mouseMonitor = nil
    }

    /// Handles mouse movement events with a debounce to avoid excessive processing.
    func handleMouseMoved() {
        mouseMoveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.processMouseMovement() }
        mouseMoveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + mouseMovedDebounceInterval, execute: workItem)
    }

    /// Handles mouse movement events to reveal or hide stashed windows.
    func processMouseMovement() {
        for (windowID, window) in stashedWindows {
            let mouseLocation = NSEvent.mouseLocation.flipY(screen: NSScreen.screens[0])
            let isWindowRevealed = revealedWindows.contains(windowID)

            if isWindowRevealed {
                // if the mouse is not over the reveal frame, hide the window
                let frame = window.computeRevealedFrame()

                if !frame.contains(mouseLocation) {
                    hideWindow(window, animate: animate)
                }
            } else {
                // if the mouse is over the stashed frame, reveal the window
                let frame = window.computeStashedFrame(peekSize: stashedWindowVisiblePadding)

                if frame.contains(mouseLocation) {
                    revealWindow(window, animate: animate)
                }
            }
        }
    }
}

// MARK: - Helpers

private extension StashManager {
    /// Cleanup references of the given window ID from the stash manager.
    func unmanage(windowID: CGWindowID) {
        stashedWindows.removeValue(forKey: windowID)
        revealedWindows.remove(windowID)
        lastRevealTime.removeValue(forKey: windowID)

        if stashedWindows.isEmpty {
            stopListeningMouseMoved()
        }
    }
}

// MARK: - Frame computation

extension StashedWindow {
    func computeStashedFrame(peekSize: CGFloat, maxPeekPercent: CGFloat = 0.2) -> CGRect {
        let currentFrame = window.frame
        let minPeekSize: CGFloat = 1
        let maxPeekSize = currentFrame.width * maxPeekPercent
        let clampedPeekSize = max(minPeekSize, min(peekSize, maxPeekSize))

        var stashedFrame = currentFrame

        switch direction {
        case .left:
            stashedFrame.origin.x = screenBounds.minX - currentFrame.width + clampedPeekSize
        case .right:
            stashedFrame.origin.x = screenBounds.maxX - clampedPeekSize
        }

        update(frame: &stashedFrame, in: direction.region)

        return stashedFrame
    }

    func computeRevealedFrame() -> CGRect {
        var revealFrame = window.frame

        switch direction {
        case .left:
            revealFrame.origin.x = screenBounds.minX
        case .right:
            revealFrame.origin.x = screenBounds.maxX - revealFrame.width
        }

        update(frame: &revealFrame, in: direction.region)

        // TODO: Check for frame.width overflow?

        return revealFrame
    }

    /// Updates the frame based on the specified region
    ///
    /// Only the y-coordinate and height are modified based on the region.
    /// The x-coordinate should be set based on the `StashDirection` before or after calling this function.
    /// In the future we may add more regions that modify the width as well.
    private func update(frame: inout CGRect, in region: StashRegion) {
        switch region {
        case .top:
            frame.origin.y = screenBounds.minY
        case .center:
            frame.origin.y = screenBounds.midY - frame.height / 2
        case .bottom:
            frame.origin.y = screenBounds.maxY - frame.height
        case .full:
            frame.origin.y = screenBounds.minY
            frame.size.height = screenBounds.height
        case .topHalf:
            frame.origin.y = screenBounds.minY
            frame.size.height = screenBounds.height / 2
        case .bottomHalf:
            frame.size.height = screenBounds.height / 2
            frame.origin.y = screenBounds.minY + screenBounds.height / 2
        }
    }
}

extension StashDirection: Equatable {
    init?(direction: WindowDirection) {
        switch direction {
        case .stashTopLeft:
            self = .left(.top)
        case .stashBottomLeft:
            self = .left(.bottom)
        case .stashCenterLeft:
            self = .left(.center)
        case .stashFullLeft:
            self = .left(.full)
        case .stashTopHalfLeft:
            self = .left(.topHalf)
        case .stashBottomHalfLeft:
            self = .left(.bottomHalf)
        case .stashTopRight:
            self = .right(.top)
        case .stashBottomRight:
            self = .right(.bottom)
        case .stashCenterRight:
            self = .right(.center)
        case .stashFullRight:
            self = .right(.full)
        case .stashTopHalfRight:
            self = .right(.topHalf)
        case .stashBottomHalfRight:
            self = .right(.bottomHalf)
        default:
            return nil
        }
    }

    var region: StashRegion {
        switch self {
        case let .left(region), let .right(region):
            region
        }
    }

    static func == (lhs: StashDirection, rhs: StashDirection) -> Bool {
        switch (lhs, rhs) {
        case let (.left(lhs), .left(rhs)):
            lhs == rhs
        case let (.right(lhs), .right(rhs)):
            lhs == rhs
        default:
            false
        }
    }
}
