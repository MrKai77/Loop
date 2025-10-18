//
//  StashManager.swift
//  Loop
//
//  Created by Guillaume Clédat on 22/05/2025.
//

import Defaults
import OSLog
import SwiftUI

/// Manages the behavior of windows that can be temporarily hidden (stashed) and revealed on screen edges.
///
/// `StashManager` orchestrates a system for "stashing" windows by moving them to the edge of a screen,
/// revealing them when the mouse approaches, and hiding them again when the mouse leaves. It handles:
/// - Window stashing logic: deciding where and how to stash windows, and ensuring non-overlapping placements.
/// - Reveal/hide logic: dynamically revealing stashed windows when the mouse is nearby, and hiding them otherwise.
/// - Input events: listens to mouse movements to manage reveal/hide behavior efficiently.
/// - Cleanup and restore: restores windows when the app terminates or when a window is explicitly unstashed.
///
/// ## Key Features:
/// - Configurable animations for reveal/hide behaviors (see `Defaults[.animateStashedWindows]`).
/// - Configurable visibility padding to determine how much of a stashed window remains visible (see `Defaults[.stashedWindowVisiblePadding]`).
/// - Smart handling of overlapping stashed windows along the same screen edge, using vertical range tolerance.
/// - Debounced and throttled mouse movement handling to avoid performance issues.
/// - Automatic focus-shifting to another window when a window is hidden (optional) (see `Defaults[.shiftFocusWhenStashed]`).
///
/// ## Constants:
/// - `mouseMovedDebounceInterval`: The minimum time interval (in seconds) between processing consecutive mouse move events.
/// - `revealThrottleInterval`: The minimum time interval (in seconds) between revealing or hiding actions for a specific window.
/// - `minimumVisibleHeightToKeepWindowStacked`:
///     - The minimum required visible vertical height (in points) between two stashed windows on the same screen edge.
///     - Ensures that multiple stashed windows do not overlap too much vertically.
///     - Allows the user to move the mouse into the stash area and target a specific window, even if windows are stacked.
///
/// ## Considerations:
/// - Currently supports only one revealed window at a time.
final class StashManager {
    static let shared = StashManager()
    private init() {}

    private let logger = Logger(category: "StashManager")

    /// Should the stashed windows be animated when revealed or hidden?
    private var animate: Bool {
        Defaults[.animateStashedWindows]
    }

    /// How many pixels of the window should be visible when stashed
    private var stashedWindowVisiblePadding: CGFloat {
        Defaults[.stashedWindowVisiblePadding]
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
    private let minimumVisibleHeightToKeepWindowStacked: CGFloat = 100

    private lazy var store: StashedWindowsStore = {
        let store = StashedWindowsStore()
        store.delegate = self
        return store
    }()

    private var lastRevealTime: [CGWindowID: Date] = [:]
    private var mouseMonitor: PassiveEventMonitor?
    private var mouseMoveWorkItem: DispatchWorkItem?

    // MARK: - Public methods

    func start() {
        store.restore()
    }

    func onApplicationWillTerminate() {
        // Move back all stashed windows back into the screen before closing the app:
        restoreAllStashedWindows(animate: false)
    }

    func onWindowDragged(_ id: CGWindowID) {
        unmanage(windowID: id)
    }

    func onConfigurationChanged() {
        for stashedWindow in store.stashed.values {
            let frame = stashedWindow.computeStashedFrame(peekSize: stashedWindowVisiblePadding)
            stashedWindow.window.setFrame(frame, animate: animate)
        }
    }

    /// Determines whether the given window action should be intercepted by the StashManager.
    ///
    /// If the action targets a stashed window that is no longer visible, the currently focused
    /// window will be stashed in its place. The stashed window is then either revealed or hidden,
    /// depending on its current state. This allows the StashManager to take over the behavior,
    /// bypassing the default flow handled by the LoopManager.
    ///
    /// - Parameter action: The window action triggered.
    /// - Returns: `true` if the action is handled by the StashManager and the normal flow should be bypassed; otherwise, `false`.
    @discardableResult
    func handleIfStashed(_ action: WindowAction, screen: NSScreen) -> Bool {
        guard action.direction == .stash else { return false }
        guard let stashedWindow = store.stashedWindow(for: action, on: screen) else { return false }
        guard !stashedWindow.window.isWindowHidden, !stashedWindow.window.isApplicationHidden else { return false }
        guard stashedWindow.screen.isSameScreen(screen) else { return false }

        logger.info("Intercepting window action for stashed window \(stashedWindow.window.debugDescription)")

        if store.isWindowRevealed(stashedWindow.id) {
            hideWindow(stashedWindow, animate: true)
        } else {
            revealWindow(stashedWindow, animate: true)
        }

        return true
    }

    func getRevealedFrameForStashedWindow(id: CGWindowID) -> CGRect? {
        store.stashed[id]?.computeRevealedFrame()
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

extension StashManager {
    /// Handles `windowResized` notification for the specified window and action.
    func onWindowResized(action: WindowAction, window: Window, screen: NSScreen) {
        if let edge = action.stashEdge {
            // Treat all screens as a unified virtual space. `getScreenForEdge` determines the appropriate screen based on the edge:
            // the leftmost screen for `.left` or the rightmost screen for `.right`. If the window's current screen differs from the target screen,
            // the function recursively adjusts the window's position to ensure it is stashed on the correct screen.
            if let screenForEdge = getScreenForEdge(currentScreen: screen, edge: edge), screen != screenForEdge {
                logger.info("StashManager: Attempting to stash window on the \(edge.debugDescription) edge, but \(screen.localizedName) is not the \(edge.debugDescription)most screen. Redirecting to the correct screen.")
                onWindowResized(action: action, window: window, screen: screenForEdge)
            } else {
                let windowToStash = StashedWindow(window: window, screen: screen, action: action)
                stash(windowToStash)
            }
        } else if action.direction == .unstash {
            // No need to reset the frame here: the frame has already been moved to the stash area
            // by the code that sent the windowResized notification.
            unstash(window.cgWindowID, resetFrame: false, resetFrameAnimated: animate)
        } else if action.direction == .undo {
            guard let action = WindowRecords.getCurrentAction(for: window) else { return }
            guard action.direction != .undo else { return }

            onWindowResized(action: action, window: window, screen: screen)
        } else if action.direction.willGrow
            || action.direction.willShrink
            || action.direction.willAdjustSize {
            // Grow, shrink, or adjustSize actions won't work for predefined stash actions, since they have a custom size.

            // If the window’s frame is updated while it’s stashed and hidden, the update will cause the window to move back on-screen
            // without adding its id to `store.revealed`. Whe need to add it back so the hide animation can be triggered.
            if isManaged(window.cgWindowID) {
                // If the window frame is fully on screen while the window ID is not in the `store.reveal` set, we add it.
                let isWindowFullyOnScreen = screen.safeScreenFrame.contains(window.frame)

                if isWindowFullyOnScreen, !store.isWindowRevealed(window.cgWindowID) {
                    store.markWindowAsRevealed(window.cgWindowID)
                }
            }
        } else if action.direction.willMove {
            // Since StashManager recomputes the frame on every show/dismiss, if the user moves a stashed window,
            // the next time the window is shown or hidden, its frame will be reset to its `Direction`.
            // This could be an improvement to consider adding later.
        } else {
            // The window will be moved by another command so it won't be stashed anymore:
            unmanage(windowID: window.cgWindowID)
        }
    }

    /// Add the given `StashWindow` to the list of monitored windows, move the window to the stashed area
    /// and start mouse moved listener if needed.
    private func stash(_ windowToStash: StashedWindow) {
        logger.info("stash \(windowToStash.window.debugDescription)")

        unstashOverlappingWindows(windowToStash)

        store.stashed[windowToStash.window.cgWindowID] = windowToStash
        hideWindow(windowToStash, animate: animate)
        startListeningMouseMoved()
    }

    /// Stop monitoring the window with the given `CGWindowID`.
    private func unstash(_ windowID: CGWindowID, resetFrame: Bool, resetFrameAnimated: Bool) {
        if let windowToUnstash = store.stashed[windowID] {
            unstash(windowToUnstash, resetFrame: resetFrame, resetFrameAnimated: resetFrameAnimated)
        } else {
            unmanage(windowID: windowID)
        }
    }

    /// Stop monitoring the window. If `resetFrame` is true, the window will be moved to its initial frame.
    private func unstash(_ window: StashedWindow, resetFrame: Bool, resetFrameAnimated: Bool) {
        logger.info("unstash \(window.window.debugDescription)")

        if resetFrame {
            let action = WindowAction(.initialFrame)
            let center = action.getFrame(window: window.window, bounds: window.screen.safeScreenFrame)

            window.window.setFrame(center, animate: resetFrameAnimated)
        }

        unmanage(windowID: window.id)
    }

    func restoreAllStashedWindows(animate: Bool) {
        for stashedWindowID in store.stashed.keys {
            unstash(stashedWindowID, resetFrame: true, resetFrameAnimated: animate)
        }
    }
}

// MARK: - Reveal and Hide

private extension StashManager {
    /// Reveals a stashed window by moving it to its reveal frame.
    func revealWindow(_ window: StashedWindow, animate: Bool) {
        guard !store.isWindowRevealed(window.id) else { return }
        guard !shouldThrottle(windowID: window.id) else { return }

        // Keep only one window as revealed
        for revealedWindowId in store.revealed {
            guard let revealedWindow = store.stashed[revealedWindowId] else { break }
            hideWindow(revealedWindow, animate: animate)
        }

        let frame = window.computeRevealedFrame()

        if shiftFocusWhenStashed {
            window.window.activate()
        }

        store.markWindowAsRevealed(window.id)
        window.window.setFrame(frame, animate: animate)

        logger.info("revealWindow \(window.window.debugDescription)")
    }

    /// Hides a stashed window by moving it to its stashed frame.
    func hideWindow(_ window: StashedWindow, animate: Bool) {
        guard !shouldThrottle(windowID: window.id) else { return }

        let frame = window.computeStashedFrame(peekSize: stashedWindowVisiblePadding)

        unfocus(window.id)
        window.window.setFrame(frame, animate: animate)
        store.markWindowAsHidden(window.id)

        logger.info("hideWindow \(window.window.debugDescription)")
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
        guard let screen = ScreenUtility.screenContaining(stashedWindow.window) ?? NSScreen.main else { return }

        let focusWindow = WindowUtility.windowList().first(where: { window in
            guard let currentWindowScreen = ScreenUtility.screenContaining(window) ?? NSScreen.main else { return false }
            guard screen.isSameScreen(currentWindowScreen) else { return false }

            return window.cgWindowID != windowID
                && !window.isApplicationHidden
                && !window.isWindowHidden
                && !window.minimized
        })

        if let focusWindow {
            logger.info("Focusing another window on the same screen: \(focusWindow.debugDescription).")
            focusWindow.activate()
        }
    }
}

// MARK: - Mouse moved listener

private extension StashManager {
    func startListeningMouseMoved() {
        guard mouseMonitor == nil else { return }

        logger.info("Listening for mouse moved events…")

        mouseMonitor = PassiveEventMonitor(
            events: [.mouseMoved],
            callback: handleMouseMoved
        )

        mouseMonitor?.start()
    }

    func stopListeningMouseMoved() {
        guard mouseMonitor != nil else { return }

        logger.info("Stopping listening for mouse moved events…")

        mouseMonitor?.stop()
        mouseMonitor = nil
    }

    /// Handles mouse movement events with a debounce to avoid excessive processing.
    func handleMouseMoved(cgEvent _: CGEvent) {
        Task { @MainActor in
            mouseMoveWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in self?.processMouseMovement() }
            mouseMoveWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + mouseMovedDebounceInterval, execute: workItem)
        }
    }

    /// Handles mouse movement events to reveal or hide stashed windows.
    func processMouseMovement() {
        let mouseLocation = NSEvent.mouseLocation.flipY(screen: NSScreen.screens[0])
        let windows = getZSortedStashedWindows()

        for window in windows {
            if store.isWindowRevealed(window.id) {
                if shouldHide(window: window, for: mouseLocation) {
                    hideWindow(window, animate: animate)
                } else {
                    break
                }
            } else if isMouseOverStashed(window: window, location: mouseLocation) {
                // The cursor is over the topmost stashed window that should be revealed
                // revealWindow will move it on screen and hide any other revealed window.
                revealWindow(window, animate: animate)
                // Only one window can be revealed at a time, so stop processing.
                break
            }
        }
    }

    /// Returns the list of stashed windows sorted by their z-index (front to back).
    /// This sorting is essential because if multiple stashed windows overlap and the cursor
    /// is over their shared area, we should only reveal the topmost window.
    private func getZSortedStashedWindows() -> [StashedWindow] {
        // Leverage the fact that WindowEngine returns windows sorted by z-index.
        // Map WindowEngine.windowList to store.stashed to retrieve the stashed windows in z-index order.
        WindowUtility.windowList().compactMap { store.stashed[$0.cgWindowID] }
    }

    /// Determines whether a revealed window should be hidden based on the mouse location.
    /// Adds a tolerance to the revealed frame to avoid hiding the window during minor cursor movement and on resize.
    private func shouldHide(window: StashedWindow, for location: CGPoint) -> Bool {
        // Hide the window if the cursor is neither over the revealedFrame nor the stashedFrame.
        let tolerance: CGFloat = 15
        let revealedFrame = window.computeRevealedFrame().insetBy(dx: -tolerance, dy: -tolerance)
        let stashedFrame = window.computeStashedFrame(peekSize: stashedWindowVisiblePadding)
        return !revealedFrame.contains(location) && !stashedFrame.contains(location)
    }

    /// Checks if the mouse is currently hovering over the stashed frame of a window.
    private func isMouseOverStashed(window: StashedWindow, location: CGPoint) -> Bool {
        let stashedFrame = window.computeStashedFrame(peekSize: stashedWindowVisiblePadding)
        return stashedFrame.contains(location)
    }
}

// MARK: - Overlap logic

private extension StashManager {
    /// Unstashes windows that overlap the newly stashed window, ensuring that all stashed windows on the same edge
    /// have sufficient non-overlapping space to remain individually accessible.
    ///
    /// This function scans all currently stashed windows (excluding the `window` just stashed) and checks for overlap
    /// using `isThereEnoughNonOverlappingSpace`.
    ///
    /// If there is not enough space, the stashed window will be unstashed (i.e., made fully visible and removed from the stash)
    /// and replaced by `windowToStash`
    func unstashOverlappingWindows(_ windowToStash: StashedWindow) {
        let newFrame = windowToStash.computeRevealedFrame()

        for (id, stashedWindow) in store.stashed {
            // windowToStash is already managed by StashManager. Can't overlap with itself.
            guard id != windowToStash.window.cgWindowID else { continue }
            // if windowToStash is not on the same edge of the screen as stashWindow, no need to check for overlap.
            guard windowToStash.action.stashEdge == stashedWindow.action.stashEdge else { continue }

            // Trying to store windowToStash in the same place as stashedWindow.
            // No need for frame comparaison, it will always overlap.
            if stashedWindow.action.isSameManipulation(as: windowToStash.action), stashedWindow.screen.isSameScreen(windowToStash.screen) {
                logger.info("Trying to stash a window in the same place as another one. Replacing…")
                unstash(stashedWindow, resetFrame: true, resetFrameAnimated: animate)
            } else {
                let currentFrame = stashedWindow.computeStashedFrame(peekSize: stashedWindowVisiblePadding)
                let tolerance = minimumVisibleHeightToKeepWindowStacked

                if !isThereEnoughNonOverlappingSpace(between: newFrame, and: currentFrame, tolerance: tolerance) {
                    logger.info("Trying to stash a window overlapping another one. Replacing…")
                    unstash(stashedWindow, resetFrame: true, resetFrameAnimated: animate)
                }
            }
        }
    }

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
    func isManaged(_ windowID: CGWindowID) -> Bool {
        store.stashed[windowID] != nil
    }

    /// Cleanup references of the given window ID from the stash manager.
    func unmanage(windowID: CGWindowID) {
        store.stashed.removeValue(forKey: windowID)
        store.markWindowAsRevealed(windowID)
        lastRevealTime.removeValue(forKey: windowID)

        if store.stashed.isEmpty {
            stopListeningMouseMoved()
        }
    }

    func getScreenForEdge(currentScreen: NSScreen, edge: StashEdge) -> NSScreen? {
        // Two screens are considered in the same "row" if they overlap vertically by at least `threshold` points
        let threshold: CGFloat = 100

        return switch edge {
        case .left:
            currentScreen.leftmostScreenInSameRow(overlapThreshold: threshold)
        case .right:
            currentScreen.rightmostScreenInSameRow(overlapThreshold: threshold)
        }
    }
}
