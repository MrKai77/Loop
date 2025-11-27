//
//  Window.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-01.
//

import Defaults
import OSLog
import SwiftUI

enum WindowError: LocalizedError {
    case invalidWindow

    var errorDescription: String {
        switch self {
        case .invalidWindow:
            "Invalid window"
        }
    }
}

final class Window {
    let axWindow: AXUIElement
    let cgWindowID: CGWindowID
    let nsRunningApplication: NSRunningApplication?

    private let logger = Logger(category: "Window")

    /// Initialize a window from an AXUIElement
    /// - Parameter element: The AXUIElement to initialize the window with. If it is not a window, an error will be thrown
    init(element: AXUIElement) throws {
        self.axWindow = element

        let pid = try axWindow.getPID()
        self.nsRunningApplication = NSWorkspace.shared.runningApplications.first {
            $0.processIdentifier == pid
        }

        self.cgWindowID = try axWindow.getWindowID()

        if role != .window,
           subrole != .standardWindow {
            throw WindowError.invalidWindow
        }

        // Check if this is a widget
        if let title = nsRunningApplication?.localizedName,
           title == "Notification Center" {
            throw WindowError.invalidWindow
        }
    }

    /// Initialize a window from a PID. The frontmost app with the given PID will be used.
    /// - Parameter pid: The PID of the app to get the window from
    convenience init(pid: pid_t) throws {
        let element = AXUIElementCreateApplication(pid)
        guard let window: AXUIElement = try element.getValue(.focusedWindow) else {
            throw WindowError.invalidWindow
        }
        try self.init(element: window)
    }

    /// Initialize a window from an entry in a dictionary returned by `CGWindowListCopyWindowInfo`.
    /// - Parameter windowInfo: The dictionary containing information about the window.
    convenience init(windowInfo: [String: AnyObject]) throws {
        // First, check if we can initialize a window simply based on its PID.
        guard
            let alpha = windowInfo[kCGWindowAlpha as String] as? Double, alpha > 0.01, // Ignore invisible windows
            let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t
        else {
            throw WindowError.invalidWindow
        }

        if let level = windowInfo[kCGWindowLayer as String] as? Int,
           level < kCGNormalWindowLevel || level > kCGDraggingWindowLevel {
            throw WindowError.invalidWindow
        }

        let element = AXUIElementCreateApplication(pid)
        guard let windows: [AXUIElement] = try element.getValue(.windows),
              !windows.isEmpty
        else {
            throw WindowError.invalidWindow
        }

        // If there’s only one window, use that as there's no need to grab its frame
        if windows.count == 1 {
            try self.init(element: windows[0])
            return
        }

        // Try to match against the frame when there are multiple windows
        if let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
           let frame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
           let match = try windows.first(where: { window in
               let position: CGPoint? = try window.getValue(.position)
               let size: CGSize? = try window.getValue(.size)
               return position == frame.origin && size == frame.size
           }) {
            try self.init(element: match)
            return
        }

        // Fallback! initialize from the first available window
        try self.init(element: windows[0])
    }

    var role: NSAccessibility.Role? {
        do {
            guard let value: String = try axWindow.getValue(.role) else {
                return nil
            }
            return NSAccessibility.Role(rawValue: value)
        } catch {
            logger.error("Failed to get role: \(error.localizedDescription)")
            return nil
        }
    }

    var subrole: NSAccessibility.Subrole? {
        do {
            guard let value: String = try axWindow.getValue(.subrole) else {
                return nil
            }
            return NSAccessibility.Subrole(rawValue: value)
        } catch {
            logger.error("Failed to get subrole: \(error.localizedDescription)")
            return nil
        }
    }

    var title: String? {
        do {
            return try axWindow.getValue(.title)
        } catch {
            logger.error("Failed to get title: \(error.localizedDescription)")
            return nil
        }
    }

    var enhancedUserInterface: Bool {
        get {
            do {
                guard let pid = try axWindow.getPID() else {
                    return false
                }
                let appWindow = AXUIElementCreateApplication(pid)
                let result: Bool? = try appWindow.getValue(.enhancedUserInterface)
                return result ?? false
            } catch {
                logger.error("Failed to get enhancedUserInterface: \(error.localizedDescription)")
                return false
            }
        }
        set {
            do {
                guard let pid = try axWindow.getPID() else {
                    return
                }
                let appWindow = AXUIElementCreateApplication(pid)
                try appWindow.setValue(.enhancedUserInterface, value: newValue)
            } catch {
                logger.error("Failed to set enhancedUserInterface: \(error.localizedDescription)")
            }
        }
    }

    /// Activate the window. This will bring it to the front and focus it if possible
    func activate() {
        // First activate the application to ensure proper window management context
        if let runningApplication = nsRunningApplication {
            runningApplication.activate(options: .activateIgnoringOtherApps)
        }

        // Then set the window as main after a brief delay to ensure proper ordering
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            try? self.axWindow.setValue(.main, value: true)
        }

        focus()
    }

    /// - Returns:
    /// `true` if the window was successfully focused; `false` otherwise.
    @discardableResult
    private func focus() -> Bool {
        guard let pid = try? axWindow.getPID() else { return false }
        return SkyLightToolBelt.focusWindow(
            windowID: cgWindowID,
            pid: pid
        )
    }

    var isAppExcluded: Bool {
        if let nsRunningApplication,
           let path = nsRunningApplication.bundleURL {
            return Defaults[.excludedApps].contains(path)
        }
        return false
    }

    var fullscreen: Bool {
        get {
            do {
                let result: NSNumber? = try axWindow.getValue(.fullScreen)
                return result?.boolValue ?? false
            } catch {
                logger.error("Failed to get fullscreen: \(error.localizedDescription)")
                return false
            }
        }
        set {
            do {
                try axWindow.setValue(.fullScreen, value: newValue)
            } catch {
                logger.error("Failed to set fullscreen: \(error.localizedDescription)")
            }
        }
    }

    func toggleFullscreen() {
        fullscreen = !fullscreen
    }

    /// Check with the `NSRunningApplication` if the app is hidden (⌘H).
    var isApplicationHidden: Bool {
        nsRunningApplication?.isHidden ?? false
    }

    /// Checks if the app has any visible windows using the `CGWindow` API.
    ///
    /// This is useful because `NSRunningApplication.isHidden` might return `false`
    /// even when the app has no visible windows (for example, if it's a menu bar app).
    /// This method iterates through the list of on-screen windows and checks if
    /// any window belongs to this application and is visible.
    ///
    /// - Returns: `true` if no visible windows are found (i.e., the app is "hidden"); `false` otherwise.
    var isWindowHidden: Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]

        guard let windowListInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return true
        }

        for windowInfo in windowListInfo {
            if let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
               let nsRunningApplication,
               pid == nsRunningApplication.processIdentifier,
               let isVisible = windowInfo[kCGWindowIsOnscreen as String] as? Bool,
               isVisible {
                return false
            }
        }

        return true
    }

    @discardableResult
    func setHidden(_ state: Bool) -> Bool {
        var result = false
        if state {
            result = nsRunningApplication?.hide() ?? false
        } else {
            result = nsRunningApplication?.unhide() ?? false
        }
        return result
    }

    @discardableResult
    func toggleHidden() -> Bool {
        if !isApplicationHidden {
            return setHidden(true)
        }
        return setHidden(false)
    }

    var minimized: Bool {
        get {
            do {
                let result: NSNumber? = try axWindow.getValue(.minimized)
                return result?.boolValue ?? false
            } catch {
                logger.error("Failed to get minimized: \(error.localizedDescription)")
                return false
            }
        }
        set {
            do {
                try axWindow.setValue(.minimized, value: newValue)
            } catch {
                logger.error("Failed to set minimized: \(error.localizedDescription)")
            }
        }
    }

    func toggleMinimized() {
        minimized = !minimized
    }

    var position: CGPoint {
        get {
            do {
                guard let result: CGPoint = try axWindow.getValue(.position) else {
                    return .zero
                }
                return result
            } catch {
                logger.error("Failed to get position: \(error.localizedDescription)")
                return .zero
            }
        }
        set {
            do {
                try axWindow.setValue(.position, value: newValue)
            } catch {
                logger.error("Failed to set position: \(error.localizedDescription)")
            }
        }
    }

    var size: CGSize {
        get {
            do {
                guard let result: CGSize = try axWindow.getValue(.size) else {
                    return .zero
                }
                return result
            } catch {
                logger.error("Failed to get size: \(error.localizedDescription)")
                return .zero
            }
        }
        set {
            do {
                try axWindow.setValue(.size, value: newValue)
            } catch {
                logger.error("Failed to set size: \(error.localizedDescription)")
            }
        }
    }

    var isResizable: Bool {
        do {
            let result: Bool = try axWindow.canSetValue(.size)
            return result
        } catch {
            logger.error("Failed to determine if window size can be set: \(error.localizedDescription)")
            return true
        }
    }

    var frame: CGRect {
        CGRect(origin: position, size: size)
    }

    /// Set the frame of this Window.
    /// - Parameters:
    ///   - rect: The new frame for the window
    ///   - animate: Whether or not to animate the window resizing
    ///   - sizeFirst: This will set the size first, which is useful when switching screens. Only does something when window animations are off
    ///   - bounds: This will prevent the window from going outside the bounds. Only does something when window animations are on
    ///   - completionHandler: Something to run after the window has been resized. This can include things like moving the cursor to the center of the window
    func setFrame(
        _ rect: CGRect,
        animate: Bool = false,
        sizeFirst: Bool = false,
        bounds: CGRect = .zero,
        completionHandler: @escaping (() -> ()) = {}
    ) {
        let enhancedUI = enhancedUserInterface

        if enhancedUI {
            let appName = nsRunningApplication?.localizedName
            logger.info("\(appName ?? "This app")'s enhanced UI will be temporarily disabled while resizing.")
            enhancedUserInterface = false
        }

        if animate {
            let animation = WindowTransformAnimation(
                rect,
                window: self,
                bounds: bounds,
                completionHandler: completionHandler
            )
            animation.startInBackground()
        } else {
            if sizeFirst {
                size = rect.size
            }
            position = rect.origin
            size = rect.size

            completionHandler()
        }

        if enhancedUI {
            enhancedUserInterface = true
        }
    }
}

extension Window: CustomStringConvertible {
    var description: String {
        let name = nsRunningApplication?.localizedName ?? title ?? "<unknown>"
        return "Window(id: \(cgWindowID), title: \(name))"
    }
}

extension Window: Equatable {
    static func == (lhs: Window, rhs: Window) -> Bool {
        lhs.cgWindowID == rhs.cgWindowID
    }
}
