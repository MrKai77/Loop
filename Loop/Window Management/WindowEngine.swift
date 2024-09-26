//
//  WindowEngine.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-16.
//

import Defaults
import SwiftUI

enum WindowEngine {
    /// Resize a Window
    /// - Parameters:
    ///   - window: Window to be resized
    ///   - direction: WindowDirection
    ///   - screen: Screen the window should be resized on
    static func resize(
        _ window: Window,
        to action: WindowAction,
        on screen: NSScreen
    ) {
        guard action.direction != .noAction else { return }
        let willChangeScreens = ScreenManager.screenContaining(window) != screen

        let windowTitle = window.nsRunningApplication?.localizedName ?? window.title ?? "<unknown>"
        print("Resizing \(windowTitle) to \(action.direction) on \(screen.localizedName)")

        // Note that this is only really useful when "Resize window under cursor" is enabled
        if Defaults[.focusWindowOnResize] {
            window.activate()
        }

        if #available(macOS 15, *), Defaults[.useSystemWindowManagerWhenAvailable] {
            SystemWindowManager.MoveAndResize.syncPadding()

            // System resizes seem to only be able to be performed on the frontmost app
            if let systemAction = action.direction.systemEquivalent, let app = window.nsRunningApplication,
               app == NSWorkspace.shared.frontmostApplication, let axMenuItem = try? systemAction.getItem(for: app) {
                try? axMenuItem.performAction(.press)
                WindowRecords.record(window, action)
                return
            } else {
                print("System action not available for \(action.direction)")
            }
        }

        // If window hasn't been recorded yet, record it, so that the user can undo the action
        if !WindowRecords.hasBeenRecorded(window) {
            WindowRecords.recordFirst(for: window)
        }

        // If the action is fullscreen, toggle fullscreen then return
        if action.direction == .fullscreen {
            window.toggleFullscreen()
            WindowRecords.record(window, action)
            return
        }
        // Otherwise, we obviously need to disable fullscreen to resize the window
        window.fullscreen = false

        // If the action is to hide or minimize, perform the action then return
        if action.direction == .hide {
            window.toggleHidden()
            return
        }

        if action.direction == .minimize {
            window.toggleMinimized()
            return
        }

        // Calculate the target frame
        let targetFrame = action.getFrame(window: window, bounds: screen.safeScreenFrame, screen: screen)
        print("Target window frame: \(targetFrame)")

        // If the action is undo, remove the last action from the window, as the target frame already contains the last action's size
        if action.direction == .undo {
            WindowRecords.removeLastAction(for: window)
        }

        // If enhancedUI is enabled, then window animations will likely lag a LOT. So, if it's enabled, force-disable animations
        let enhancedUI = window.enhancedUserInterface
        let animate = Defaults[.animateWindowResizes] && !enhancedUI

        WindowRecords.record(window, action)

        // If the window is one of Loop's windows, resize it using the actual NSWindow, preventing crashes
        if window.nsRunningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier,
           let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.level.rawValue <= NSWindow.Level.floating.rawValue }) {
            NSAnimationContext.runAnimationGroup { context in
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.33, 1, 0.68, 1)
                window.animator().setFrame(targetFrame.flipY(screen: .screens[0]), display: false)
            }
            return
        }

        let usePadding = Defaults[.enablePadding] && (Defaults[.paddingMinimumScreenSize] == 0 || screen.diagonalSize > Defaults[.paddingMinimumScreenSize])

        // If the window is being moved via shortcuts (move right, move left etc.), then the bounds will be zero.
        // This is because the window *can* be moved off-screen in this case.
        // Otherwise padding will be applied if needed.
        let bounds = if action.direction.willMove {
            CGRect.zero
        } else if usePadding {
            Defaults[.padding].apply(on: screen.safeScreenFrame)
        } else {
            screen.safeScreenFrame
        }

        window.setFrame(
            targetFrame,
            animate: animate,
            sizeFirst: willChangeScreens,
            bounds: bounds
        ) {
            // Fixes an issue where window isn't resized correctly on multi-monitor setups
            // If window is being animated, then the size is very likely to already be correct, as what's really happening is window.setFrame at a really high rate.
            if !animate, !window.frame.approximatelyEqual(to: targetFrame) {
                print("Backup resizing...")
                window.setFrame(targetFrame)
            }

            // If window's minimum size exceeds the screen bounds, push it back in
            WindowEngine.handleSizeConstrainedWindow(window: window, bounds: bounds)
        }

        // Move cursor to center of window if user has enabled it
        if Defaults[.moveCursorWithWindow] {
            CGWarpMouseCursorPosition(targetFrame.center)
        }
    }

    /// Get the target window, depending on the user's preferences. This could be the frontmost window, or the window under the cursor.
    /// - Returns: The target window
    static func getTargetWindow() -> Window? {
        var result: Window?

        do {
            if Defaults[.resizeWindowUnderCursor],
               let mouseLocation = CGEvent.mouseLocation,
               let window = try WindowEngine.windowAtPosition(mouseLocation) {
                result = window
            }
        } catch {
            print("Failed to get window at cursor: \(error.localizedDescription)")
        }

        if result == nil {
            do {
                result = try WindowEngine.getFrontmostWindow()
            } catch {
                print("Failed to get frontmost window: \(error.localizedDescription)")
            }
        }

        return result
    }

    /// Get the frontmost Window
    /// - Returns: Window?
    static func getFrontmostWindow() throws -> Window? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.isActive }) else {
            return nil
        }
        return try Window(pid: app.processIdentifier)
    }

    /// Get the Window at a given position.
    /// - Parameter position: The position to check for
    /// - Returns: The window at the given position, if any
    static func windowAtPosition(_ position: CGPoint) throws -> Window? {
        // If we can find the window at a point using the Accessibility API, return it
        if let element = try AXUIElement.systemWide.getElementAtPosition(position),
           let windowElement: AXUIElement = try element.getValue(.window) {
            return try Window(element: windowElement)
        }

        // If the previous method didn't work, loop through all windows on-screen and return the first one that contains the desired point
        let windowList = WindowEngine.windowList
        if let window = (windowList.first { $0.frame.contains(position) }) {
            return window
        }

        return nil
    }

    /// Get a list of all windows currently shown, that are likely to be resizable by Loop.
    static var windowList: [Window] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as NSArray? as? [[String: AnyObject]] else {
            return []
        }

        var windowList: [Window] = []
        for window in list {
            if let pid = window[kCGWindowOwnerPID as String] as? Int32, let window = try? Window(pid: pid) {
                windowList.append(window)
            }
        }

        return windowList
    }

    /// This function is used to calculate the Y offset for a window to be "macOS centered" on the screen
    /// It is identical to `NSWindow.center()`.
    /// - Parameters:
    ///   - windowHeight: Height of the window to be resized
    ///   - screenHeight: Height of the screen the window will be resized on
    /// - Returns: The Y offset of the window, to be added onto the screen's midY point.
    static func getMacOSCenterYOffset(_ windowHeight: CGFloat, screenHeight: CGFloat) -> CGFloat {
        let halfScreenHeight = screenHeight / 2
        let windowHeightPercent = windowHeight / screenHeight
        return (0.5 * windowHeightPercent - 0.5) * halfScreenHeight
    }

    /// Will move a window back onto the screen. To be run AFTER a window has been resized.
    /// - Parameters:
    ///   - window: Window
    ///   - screenFrame: The screen's frame
    private static func handleSizeConstrainedWindow(window: Window, bounds: CGRect) {
        guard bounds != .zero else {
            return
        }

        var windowFrame = window.frame

        // If the window is fully shown on the screen
        if windowFrame.maxX <= bounds.maxX,
           windowFrame.maxY <= bounds.maxY {
            return
        }

        if windowFrame.maxX > bounds.maxX {
            windowFrame.origin.x = bounds.maxX - windowFrame.width
        }

        if windowFrame.maxY > bounds.maxY {
            windowFrame.origin.y = bounds.maxY - windowFrame.height
        }

        window.position = windowFrame.origin
    }
}
