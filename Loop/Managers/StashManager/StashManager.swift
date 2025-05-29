//
//  StashManager.swift
//  Loop
//
//  Created by Guillaume Clédat on 22/05/2025.
//

import Defaults
import SwiftUI

/// `StashManager` is responsible "stashing" app windows on the edge of the sceen
///
/// ## Purpose:
/// The main objective of `StashManager` is to allow windows to be temporarily hidden (stashed) off-screen, with a small
/// visible "peek" area. When the user moves the cursor near this peek area, the window is revealed (unstashed).
/// This behavior was made to reduce screen clutter while maintaining quick access to important windows.
///
/// ## Key Responsibilities:
/// - **Stashing windows**: Moves windows to a hidden area along a screen edge, with a small portion visible.
/// - **Revealing windows**: When the mouse hovers over the peek area, the window is fully revealed.
/// - **Hiding windows**: If the mouse moves away from a revealed window, it returns to the stash position.
/// - **Overlap handling**: Ensures multiple stashed windows do not overlap excessively, using a configurable tolerance.
///
/// ## How it Works:
/// 1. **Initialization**:
///    - Subscribes to `.UIDirectionUpdated` notifications, which indicate a window as been moved or resized by an user action.
///      If this action is related to the stash logic, the `StashManager` will act accordingly.
///    - Maintains a dictionary of currently stashed windows (`stashedWindows`), keyed by `CGWindowID`.
///    - Tracks revealed windows (`revealedWindows`) and the last reveal time for throttling.
/// 3. **Mouse Monitoring**:
///    - Uses a global `NSEventMonitor` to track mouse movements.
///    - Applies debounce and throttle intervals to control reveal/hide frequency.
///    - Determines which window (if any) should be revealed based on cursor position and z-index order.
/// 4. **Stashing Logic**:
///    - Moves a window to the stashed area based on its direction (`StashDirection`).
///    - Checks for overlapping with other stashed windows and unstashes conflicting ones.
///    - Applies optional animation during transitions.
/// 5. **Unstashing Logic**:
///    - Restores a window from stash, optionally resetting its position to the center of the screen.
///    - Stops monitoring windows that are unstashed or unmanaged.
/// 6. **Overlap Handling**:
///    - Checks whether two windows overlap or have sufficient non-overlapping space based on a configured `tolerance`.
/// 7. **Focus Management**:
///    - Attempts to shift focus to the topmost window on the same screen when a stashed window is hidden.
///
/// ## Configuration:
/// Some behavior of `StashManager` can be user defined:
/// - `Defaults[.animateStashedWindows]`: Whether animations should be used when revealing or hiding windows.
/// - `Defaults[.stashedWindowVisiblePadding]`: Amount (in points) of the window's edge that remains visible when it is stashed (peek area).
/// - `Defaults[.shiftFocusWhenStashed]`: Attempts to shift focus to the topmost window on the same screen when a stashed window is hidden.
/// - `Defaults[.enablePadding]` and `Defaults[.padding]`: Additional padding applied to window positioning to ensure consistent spacing.
///
/// Other behaviors are defined by constants:
/// - `mouseMovedDebounceInterval`: The minimum time interval (in seconds) between processing consecutive mouse move events.
/// - `revealThrottleInterval`: The minimum time interval (in seconds) between revealing or hiding actions for a specific window.
/// - `minimunVisibleHeightToKeepWindowStacked`:
///     - The minimum required visible vertical height (in points) between two stashed windows on the same screen edge.
///     - Ensures that multiple stashed windows do not overlap too much vertically.
///     - Allows the user to move the mouse into the stash area and target a specific window, even if windows are stacked.
///
/// ## Considerations:
/// - Currently supports only one revealed window at a time.
/// - The `unfocus` method is incomplete and requires virtual space awareness for precise focus handling.
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
        Defaults[.enablePadding] == true ? Defaults[.padding] : .zero
    }

    private var shiftFocusWhenStashed: Bool {
        Defaults[.shiftFocusWhenStashed]
    }

    /// The time interval to debounce mouse moved events to avoid excessive processing.
    private let mouseMovedDebounceInterval: TimeInterval = 0.05

    /// The throttle interval for revealing/hiding windows when the mouse moves.
    private let revealThrottleInterval: TimeInterval = 0.1

    /// Two windows can be stacked along the same edge of the screen as long as there is enough non-overlapping space
    /// to allow the user to easily position the cursor over either window.
    private let minimunVisibleHeightToKeepWindowStacked: CGFloat = 100

    private lazy var store: StashedWindowsStore = {
        let store = StashedWindowsStore()
        store.delegate = self
        return store
    }()

    private var lastRevealTime: [CGWindowID: Date] = [:]
    private var mouseMonitor: NSEventMonitor?
    private var mouseMoveWorkItem: DispatchWorkItem?

    func start() {
        Notification.Name.UIDirectionUpdated.onReceive { [weak self] obj in
            guard let action = obj.userInfo?["action"] as? WindowAction else { return }
            guard let window = obj.userInfo?["window"] as? Window else { return }
            guard let screen = obj.userInfo?["screen"] as? NSScreen else { return }

            self?.onUIDirectionUpdated(action: action, window: window, screen: screen)
        }

        store.restore()
    }

    func onApplicationWillTerminate() {
        // Move back all stashed windows back into the screen before closing the app:
        restoreAllStashedWindows(animate: false)
    }

    func onWindowDragged(_ id: CGWindowID) {
        unmanage(windowID: id)
    }

    deinit {
        mouseMoveWorkItem?.cancel()
        stopListeningMouseMoved()
        restoreAllStashedWindows(animate: false)
    }
}

// MARK: - StashedWindowsStoreDelegate

extension StashManager: StashedWindowsStoreDelegate {
    func onStashedWindowsRestored() {
        if !store.stashed.isEmpty {
            startListeningMouseMoved()
        }
    }
}

// MARK: - Stash and Unstash

private extension StashManager {
    /// Handles `UIDirectionUpdated` notification for the specified window and action.
    private func onUIDirectionUpdated(action: WindowAction, window: Window, screen: NSScreen) {
        if let direction = StashDirection(direction: action.direction) {
            guard hasNoAdjacentScreen(on: direction, currentScreen: screen) else {
                print("StashManager: Can't stash a window if there is an adjacent screen on that side.")
                return
            }

            let bounds = WindowAction.getBounds(from: screen.safeScreenFrame, disablePadding: false, screen: screen)
            let windowToStash = StashedWindow(window: window, screenBounds: bounds, direction: direction)

            stash(windowToStash)
        } else if action.direction == .unstash {
            // No need to reset the frame here: the frame has already been moved to the stash area
            // by the code that sent the UIDirectionUpdated notification.
            unstash(window.cgWindowID, resestFrame: false, resetFrameAnimated: animate)
        } else if action.direction == .undo {
            guard let action = WindowRecords.getCurrentAction(for: window) else { return }
            guard action.direction != .undo else { return }

            onUIDirectionUpdated(action: action, window: window, screen: screen)
        } else {
            // TODO: Handle .smaller, .bigger, .shrink, .grow, .move
            // The window will be moved or resized by another command so it won't be stashed anymore:
            unmanage(windowID: window.cgWindowID)
        }
    }

    /// Add the given `StashWindow` to the list of monitored windows, move the window to the stashed area
    /// and start mouse moved listener if needed.
    func stash(_ windowToStash: StashedWindow) {
        print("StashManager: stash \(windowToStash.window)")

        unstashOverlappingWindows(windowToStash)

        store.stashed[windowToStash.window.cgWindowID] = windowToStash
        hideWindow(windowToStash, animate: animate)
        startListeningMouseMoved()
    }

    func unstashOverlappingWindows(_ windowToStash: StashedWindow) {
        let newFrame = windowToStash.computeRevealedFrame(windowPadding: padding.window)

        for (id, stashedWindow) in store.stashed {
            // windowToStash is already managed by StashManager. Can't overlap with itself.
            guard id != windowToStash.window.cgWindowID else { continue }
            // if windowToStash is not on the same edge of the screen as stashWindow, no need to check for overlap.
            guard windowToStash.direction.isSameEdgeAs(stashedWindow.direction) else { continue }

            // Trying to store windowToStash in the same place as stashedWindow.
            // No need for frame comparaison, it will always overlap.
            if stashedWindow.direction == windowToStash.direction {
                unstash(stashedWindow, resetFrame: true, resetFrameAnimated: animate)
            } else {
                let currentFrame = stashedWindow.computeRevealedFrame(windowPadding: padding.window)
                let tolerance = minimunVisibleHeightToKeepWindowStacked

                if !isThereEnoughNonOverlappingSpace(between: newFrame, and: currentFrame, tolerance: tolerance) {
                    unstash(stashedWindow, resetFrame: true, resetFrameAnimated: animate)
                }
            }
        }
    }

    /// Stop monitoring the window with the given `CGWindowID`.
    func unstash(_ windowID: CGWindowID, resestFrame: Bool, resetFrameAnimated: Bool) {
        if let windowToUnstash = store.stashed[windowID] {
            unstash(windowToUnstash, resetFrame: resestFrame, resetFrameAnimated: resetFrameAnimated)
        } else {
            unmanage(windowID: windowID)
        }
    }

    /// Stop monitoring the window. If `resetFrame` is true, the window will be moved in the center of the screen.
    func unstash(_ window: StashedWindow, resetFrame: Bool, resetFrameAnimated: Bool) {
        print("StashManager: unstash \(window.window)")

        if resetFrame {
            let windowSize = window.window.size
            let x = window.screenBounds.midX - (windowSize.width / 2)
            let y = window.screenBounds.midY - (windowSize.height / 2)
            let center = CGRect(origin: CGPoint(x: x, y: y), size: windowSize)

            window.window.setFrame(center, animate: resetFrameAnimated)
        }

        unmanage(windowID: window.window.cgWindowID)
    }

    func restoreAllStashedWindows(animate: Bool) {
        for stashedWindowID in store.stashed.keys {
            unstash(stashedWindowID, resestFrame: true, resetFrameAnimated: animate)
        }
    }
}

// MARK: - Reveal and Hide

private extension StashManager {
    /// Reveals a stashed window by moving it to its reveal frame.
    func revealWindow(_ window: StashedWindow, animate: Bool) {
        let windowID = window.window.cgWindowID

        guard !store.revealed.contains(windowID) else { return }
        guard !shouldThrottle(windowID: windowID) else { return }

        // Keep only one window as revealed
        for revealedWindowId in store.revealed {
            guard let revealedWindow = store.stashed[revealedWindowId] else { break }
            hideWindow(revealedWindow, animate: animate)
        }

        let frame = window.computeRevealedFrame(windowPadding: padding.window)

        window.window.activate()
        store.revealed.insert(windowID)
        window.window.setFrame(frame, animate: animate)

        print("StashManager: revealWindow \(window.window)")
    }

    /// Hides a stashed window by moving it to its stashed frame.
    func hideWindow(_ window: StashedWindow, animate: Bool) {
        let windowID = window.window.cgWindowID

        guard !shouldThrottle(windowID: windowID) else { return }

        let frame = window.computeStashedFrame(peekSize: stashedWindowVisiblePadding, padding: padding)

        unfocus(windowID)
        window.window.setFrame(frame, animate: animate)
        store.revealed.remove(windowID)

        print("StashManager: hideWindow \(window.window)")
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

    /// Attempts to unfocus (i.e., shift focus away from) a specified window.
    ///
    /// This method looks for the first (topmost) visible, non-minimized window on the same screen as the specified window,
    /// and tries to activate it (i.e., bring it to the foreground).
    func unfocus(_ windowID: CGWindowID) {
        guard shiftFocusWhenStashed else { return }
        guard let stashedWindow = store.stashed[windowID] else { return }
        guard let screen = ScreenManager.screenContaining(stashedWindow.window) ?? NSScreen.main else { return }

        let focusWindow = WindowEngine.windowList.first(where: { window in
            guard let currentWindowScreen = ScreenManager.screenContaining(window) ?? NSScreen.main else { return false }
            guard screen.isSameScreen(currentWindowScreen) else { return false }

            return window.cgWindowID != windowID
                && !window.isHidden
                && !window.isWindowHidden
                && !window.minimized
        })

        if let focusWindow {
            print("StashManager: Focusing another window on the same screen: \(focusWindow).")
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
    /// We use the fact that `WindowEngine.windowList` returns windows sorted by z-index.
    /// This sorting is essential because if multiple stashed windows overlap and the cursor
    /// is over their shared area, we should only reveal the topmost window.
    func processMouseMovement() {
        let mouseLocation = NSEvent.mouseLocation.flipY(screen: NSScreen.screens[0])

        // get stashedWindows sorted by z-index
        let zIndexSortedStashedWindows = WindowEngine.windowList.compactMap { store.stashed[$0.cgWindowID] }

        for window in zIndexSortedStashedWindows {
            let isWindowRevealed = store.revealed.contains(window.window.cgWindowID)
            let stashedFrame = window.computeStashedFrame(peekSize: stashedWindowVisiblePadding, padding: padding)

            if isWindowRevealed {
                let revealedFrame = window.computeRevealedFrame()

                // Hide the window if the cursor is neither over the revealedFrame nor the stashedFrame.
                if !revealedFrame.contains(mouseLocation), !stashedFrame.contains(mouseLocation) {
                    hideWindow(window, animate: animate)
                } else {
                    // If the cursor is over the topmost revealed window, no need to process other windows below.
                    break
                }
            } else if stashedFrame.contains(mouseLocation) {
                // The cursor is over the topmost stashed window that should be revealed.
                // revealWindow will move it on screen and hide any other revealed window.
                revealWindow(window, animate: animate)
                // Only one window can be revealed at a time, so stop processing.
                break
            }
        }
    }
}

// MARK: - Overlap logic

private extension StashManager {
    /// Determines whether two rectangles have enough non-overlapping space between them.
    ///
    /// This function compares the vertical ranges (y-axis) of two rectangles, `rect1` and `rect2`,
    /// and checks if they are either non-overlapping or sufficiently offset vertically by at least
    /// a given `tolerance` value. This ensures that if windows are stashed along the same edge of the screen,
    /// they do not overlap each other and leave enough visible space (as defined by `tolerance`).
    ///
    /// - Parameters:
    ///   - rect1: The first rectangle representing a stashed window's frame.
    ///   - rect2: The second rectangle representing another window's frame.
    ///   - tolerance: The minimum number of pixels that must separate the two windows (in the vertical direction).
    ///
    /// - Returns: `true` if the two rectangles do not overlap or are separated by at least `tolerance` pixels;
    ///            `false` otherwise.
    func isThereEnoughNonOverlappingSpace(between rect1: CGRect, and rect2: CGRect, tolerance: CGFloat) -> Bool {
        let range1 = rect1.minY...rect1.maxY
        let range2 = rect2.minY...rect2.maxY

        return areRangesNonOverlappingByAtLeast(tolerance, range1, range2)
    }

    /// Determines if two ranges are either non-overlapping or overlap in such a way
    /// that the shorter range extends at least `tolerance` units beyond the longer range.
    /// - Parameters:
    ///   - tolerance: The minimum required extension (in units) beyond the longer range for an overlap to be acceptable.
    ///   - range1: The first closed range.
    ///   - range2: The second closed range.
    /// - Returns: `true` if the ranges do not overlap, or if the shorter range extends
    ///            at least `tolerance` units either below or above the longer range.
    func areRangesNonOverlappingByAtLeast(_ tolerance: CGFloat, _ range1: ClosedRange<CGFloat>, _ range2: ClosedRange<CGFloat>) -> Bool {
        // Check if ranges do not overlap
        if range1.upperBound < range2.lowerBound || range2.upperBound < range1.lowerBound {
            return true
        }

        // Determine longer and shorter ranges
        let length1 = range1.upperBound - range1.lowerBound
        let length2 = range2.upperBound - range2.lowerBound

        let topRange: ClosedRange<CGFloat>
        let bottomRange: ClosedRange<CGFloat>

        if length1 >= length2 {
            (topRange, bottomRange) = (range1, range2)
        } else {
            (topRange, bottomRange) = (range2, range1)
        }

        // Calculate bottom extension
        let belowExtension = bottomRange.lowerBound < topRange.lowerBound
            ? topRange.lowerBound - bottomRange.lowerBound
            : 0

        // Calculate above extension
        let aboveExtension = bottomRange.upperBound > topRange.upperBound
            ? bottomRange.upperBound - topRange.upperBound
            : 0

        return belowExtension >= tolerance || aboveExtension >= tolerance
    }
}

// MARK: - Helpers

private extension StashManager {
    /// Cleanup references of the given window ID from the stash manager.
    func unmanage(windowID: CGWindowID) {
        store.stashed.removeValue(forKey: windowID)
        store.revealed.remove(windowID)
        lastRevealTime.removeValue(forKey: windowID)

        if store.stashed.isEmpty {
            stopListeningMouseMoved()
        }
    }

    func hasNoAdjacentScreen(on direction: StashDirection, currentScreen: NSScreen) -> Bool {
        switch direction {
        case .left:
            !currentScreen.hasScreenOnLeft
        case .right:
            !currentScreen.hasScreenOnRight
        }
    }
}
