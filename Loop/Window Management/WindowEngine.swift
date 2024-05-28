//
//  WindowEngine.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-16.
//

import SwiftUI
import Defaults

struct WindowEngine {
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

        if !WindowRecords.hasBeenRecorded(window) {
            WindowRecords.recordFirst(for: window)
        }

        if action.direction == .fullscreen {
            window.toggleFullscreen()
            WindowRecords.record(window, action)
            return
        }
        window.setFullscreen(false)

        if action.direction == .hide {
            window.toggleHidden()
            return
        }

        if action.direction == .minimize {
            window.toggleMinimized()
            return
        }

        let targetFrame = action.getFrame(window: window, bounds: screen.safeScreenFrame)

        if action.direction == .undo {
            WindowRecords.removeLastAction(for: window)
        }

        print("Target window frame: \(targetFrame)")

        let enhancedUI = window.enhancedUserInterface ?? false
        let animate = Defaults[.animateWindowResizes] && !enhancedUI

        if window.nsRunningApplication == NSRunningApplication.current,
           let window = NSApp.keyWindow {
            var newFrame = targetFrame
            newFrame.size = window.frame.size

            if newFrame.maxX > screen.safeScreenFrame.maxX {
                newFrame.origin.x = screen.safeScreenFrame.maxX - newFrame.width - Defaults[.padding].right
            }

            if newFrame.maxY > screen.safeScreenFrame.maxY {
                newFrame.origin.y = screen.safeScreenFrame.maxY - newFrame.height - Defaults[.padding].bottom
            }

            NSAnimationContext.runAnimationGroup { context -> Void in
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.33, 1, 0.68, 1)
                window.animator().setFrame(newFrame.flipY(screen: .screens[0]), display: false)
            }

            return
        }

        window.setFrame(
            targetFrame,
            animate: animate,
            sizeFirst: willChangeScreens,
            bounds: screen.safeScreenFrame
        ) {
            // If animations are disabled, check if the window needs extra resizing
            if !animate {
                // Fixes an issue where window isn't resized correctly on multi-monitor setups
                if !window.frame.approximatelyEqual(to: targetFrame) {
                    print("Backup resizing...")
                    window.setFrame(targetFrame)
                }
            }

            WindowEngine.handleSizeConstrainedWindow(window: window, screenFrame: screen.safeScreenFrame)
        }

        WindowRecords.record(window, action)
    }

    static func getTargetWindow() -> Window? {
        var result: Window?

        if Defaults[.resizeWindowUnderCursor],
           let mouseLocation = CGEvent.mouseLocation,
           let window = WindowEngine.windowAtPosition(mouseLocation) {
            result = window
        }

        if result == nil {
           result = WindowEngine.frontmostWindow
        }

        return result
    }

    /// Get the frontmost Window
    /// - Returns: Window?
    static var frontmostWindow: Window? {
        guard
            let app = NSWorkspace.shared.runningApplications.first(where: { $0.isActive }),
            let window = Window(pid: app.processIdentifier)
        else {
            return nil
        }
        return window
    }

    static func windowAtPosition(_ position: CGPoint) -> Window? {
        if let element = AXUIElement.systemWide.getElementAtPosition(position),
           let windowElement = element.getValue(.window),
           // swiftlint:disable:next force_cast
           let window = Window(element: windowElement as! AXUIElement) {
            return window
        }

        let windowList = WindowEngine.windowList
        if let window = (windowList.first { $0.frame.contains(position) }) {
            return window
        }

        return nil
    }

    static var windowList: [Window] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as NSArray? as? [[String: AnyObject]] else {
            return []
        }

        var windowList: [Window] = []
        for window in list {
            if let pid = window[kCGWindowOwnerPID as String] as? Int32,
               let window = Window(pid: pid) {
                windowList.append(window)
            }
        }

        return windowList
    }

    static func getMacOSCenterYOffset(_ windowHeight: CGFloat, screenHeight: CGFloat) -> CGFloat {
        let halfScreenHeight = screenHeight / 2
        let windowHeightPercent = windowHeight / screenHeight
        return (0.5 * windowHeightPercent - 0.5) * halfScreenHeight
    }

    /// Will move a window back onto the screen. To be run AFTER a window has been resized.
    /// - Parameters:
    ///   - window: Window
    ///   - screenFrame: The screen's frame
    private static func handleSizeConstrainedWindow(window: Window, screenFrame: CGRect) {
        let windowFrame = window.frame
        // If the window is fully shown on the screen
        if (windowFrame.maxX <= screenFrame.maxX) && (windowFrame.maxY <= screenFrame.maxY) {
            return
        }

        // If not, then Loop will auto re-adjust the window size to be fully shown on the screen
        var fixedWindowFrame = windowFrame

        if fixedWindowFrame.maxX > screenFrame.maxX {
            fixedWindowFrame.origin.x = screenFrame.maxX - fixedWindowFrame.width - Defaults[.padding].right
        }

        if fixedWindowFrame.maxY > screenFrame.maxY {
            fixedWindowFrame.origin.y = screenFrame.maxY - fixedWindowFrame.height - Defaults[.padding].bottom
        }

        window.setPosition(fixedWindowFrame.origin)
    }
}
