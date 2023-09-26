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
    static func resize(_ window: Window, to direction: WindowDirection, _ screen: NSScreen) {
        guard direction != .noAction else { return }

        if direction == .fullscreen {
            if window.isFullscreen {
                window.setFullscreen(false)
            } else {
                window.setFullscreen(true)
            }

            WindowRecords.recordDirection(window, direction)
            return
        }

        window.setFullscreen(false)

        if !WindowRecords.hasBeenRecorded(window) {
            WindowRecords.recordFirst(for: window)
        }

        let oldWindowFrame = window.frame
        guard let screenFrame = screen.safeScreenFrame,
              let currentWindowFrame = WindowEngine.generateWindowFrame(oldWindowFrame, screenFrame, direction) else {
            return
        }
        var targetWindowFrame = WindowEngine.applyPadding(currentWindowFrame, direction)

        var animate =  Defaults[.animateWindowResizes]
        if animate {
            if PermissionsManager.ScreenRecording.getStatus() == false {
                PermissionsManager.ScreenRecording.requestAccess()
                animate = false
                return
            }

            // Calculate the window's minimum window size and change the target accordingly
            window.getMinSize(screen: screen) { minSize in
                if (targetWindowFrame.minX + minSize.width) > screen.frame.maxX {
                    targetWindowFrame.origin.x = screen.frame.maxX - minSize.width - Defaults[.windowPadding]
                }

                if (targetWindowFrame.minY + minSize.height) > screen.frame.maxY {
                    targetWindowFrame.origin.y = screen.frame.maxY - minSize.height - Defaults[.windowPadding]
                }

                window.setFrame(targetWindowFrame, animate: true)
                WindowRecords.recordDirection(window, direction)
            }
        } else {
            window.setFrame(targetWindowFrame)
            WindowEngine.handleSizeConstrainedWindow(window: window, screenFrame: screenFrame)
            WindowRecords.recordDirection(window, direction)
        }
    }

    /// Get the frontmost Window
    /// - Returns: Window?
    static var frontmostWindow: Window? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.isActive }),
              let window = Window(pid: app.processIdentifier) else { return nil }

        #if DEBUG
        print("===== NEW WINDOW =====")
        print("Frontmost window: \(window.cgWindowID)")
        print("Process ID: \(window.processID)")
        print("kAXWindowRole: \(window.role?.rawValue ?? "N/A")")
        print("kAXStandardWindowSubrole: \(window.subrole?.rawValue ?? "N/A")")
        #endif

        return window
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

    static func windowAtPosition(_ position: CGPoint) -> Window? {
        if let element = AXUIElement.systemWide.getElementAtPosition(position),
           let window = Window(element: element) {
            return window
        }

        let windowList = WindowEngine.windowList
        if let window = (windowList.first { $0.frame.contains(position) }) {
            return window
        }

        return nil
    }

    /// Generate a window frame using the provided WindowDirection
    /// - Parameters:
    ///   - windowFrame: The window's current frame. Used when centering a window
    ///   - screenFrame: The frame of the screen you want the window to be resized on
    ///   - direction: WindowDirection
    /// - Returns: A CGRect of the generated frame. If direction was .noAction, nil is returned.
    private static func generateWindowFrame(
        _ windowFrame: CGRect,
        _ screenFrame: CGRect,
        _ direction: WindowDirection
    ) -> CGRect? {
        let screenWidth = screenFrame.size.width
        let screenHeight = screenFrame.size.height

        var newWindowFrame: CGRect = CGRect(
            x: screenFrame.origin.x,
            y: screenFrame.origin.y,
            width: 0,
            height: 0
        )

        switch direction {
        case .center:
            newWindowFrame = CGRect(
                x: screenFrame.midX - windowFrame.width/2,
                y: screenFrame.midY - windowFrame.height/2,
                width: windowFrame.width,
                height: windowFrame.height
            )
        default:
            guard let frameMultiplyValues = direction.frameMultiplyValues else { return nil}
            newWindowFrame.origin.x += screenWidth * frameMultiplyValues.minX
            newWindowFrame.origin.y += screenHeight * frameMultiplyValues.minY
            newWindowFrame.size.width += screenWidth * frameMultiplyValues.width
            newWindowFrame.size.height += screenHeight * frameMultiplyValues.height
        }

        return newWindowFrame
    }

    /// Apply padding on a CGRect, using the provided WindowDirection
    /// - Parameters:
    ///   - windowFrame: The frame the window WILL be resized to
    ///   - direction: The direction the window WILL be resized to
    /// - Returns: CGRect with padding applied
    private static func applyPadding(_ windowFrame: CGRect, _ direction: WindowDirection) -> CGRect {
        var paddingAppliedRect = windowFrame
        for side in [Edge.top, Edge.bottom, Edge.leading, Edge.trailing] {
            if direction.edgesTouchingScreen.contains(side) {
                paddingAppliedRect.inset(side, amount: Defaults[.windowPadding])
            } else {
                paddingAppliedRect.inset(side, amount: Defaults[.windowPadding] / 2)
            }
        }
        return paddingAppliedRect
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
            fixedWindowFrame.origin.x = screenFrame.maxX - fixedWindowFrame.width - Defaults[.windowPadding]
        }

        if fixedWindowFrame.maxY > screenFrame.maxY {
            fixedWindowFrame.origin.y = screenFrame.maxY - fixedWindowFrame.height - Defaults[.windowPadding]
        }

        window.setPosition(fixedWindowFrame.origin)
    }
}

extension CGRect {
    mutating func inset(_ side: Edge, amount: CGFloat) {
        switch side {
        case .top:
            self.origin.y += amount
            self.size.height -= amount
        case .leading:
            self.origin.x += amount
            self.size.width -= amount
        case .bottom:
            self.size.height -= amount
        case .trailing:
            self.size.width -= amount
        }
    }
}
