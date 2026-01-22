//
//  Window.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-01.
//

import Defaults
import Scribe
import SwiftUI

enum WindowError: LocalizedError {
    case sheetWindow
    case blockedBundleID
    case cannotGetWindow
    case filteredOutFromWindowInfo

    var errorDescription: String? {
        switch self {
        case .sheetWindow:
            "Invalid window: sheet"
        case .blockedBundleID:
            "Invalid window: blocked bundle ID"
        case .cannotGetWindow:
            "Could not get the element's window"
        case .filteredOutFromWindowInfo:
            "Filtered out from window info"
        }
    }
}

final class Window {
    let axWindow: AXUIElement
    let cgWindowID: CGWindowID
    let nsRunningApplication: NSRunningApplication?

    /// Initialize a window from an AXUIElement
    /// - Parameter element: The AXUIElement to initialize the window with. If it is not a window, an error will be thrown
    init(element: AXUIElement) throws {
        self.axWindow = element
        self.cgWindowID = try element.getWindowID()
        let pid = try axWindow.getPID()
        self.nsRunningApplication = NSWorkspace.shared.runningApplications.first { $0.processIdentifier == pid }

        guard role != .sheet else {
            throw WindowError.sheetWindow
        }

        let invalidBundleIdentifiers: [String] = [
            "com.apple.PIPAgent", // PIP windows
            "com.apple.notificationcenterui" // Widgets & Notification Center
        ]

        if let bundleIdentifier = nsRunningApplication?.bundleIdentifier,
           invalidBundleIdentifiers.contains(bundleIdentifier) {
            throw WindowError.blockedBundleID
        }
    }

    /// Initialize a window from a PID. The frontmost app with the given PID will be used.
    /// - Parameter pid: The PID of the app to get the window from
    convenience init(pid: pid_t) throws {
        let element = AXUIElementCreateApplication(pid)
        guard let window: AXUIElement = try element.getValue(.focusedWindow) else {
            throw WindowError.cannotGetWindow
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
            throw WindowError.filteredOutFromWindowInfo
        }

        if let level = windowInfo[kCGWindowLayer as String] as? Int,
           level < kCGNormalWindowLevel || level > kCGDraggingWindowLevel {
            throw WindowError.filteredOutFromWindowInfo
        }

        let element = AXUIElementCreateApplication(pid)
        guard let windows: [AXUIElement] = try element.getValue(.windows),
              !windows.isEmpty
        else {
            throw WindowError.cannotGetWindow
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
            Log.error("Failed to get role: \(error.localizedDescription)", category: .window)
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
            Log.error("Failed to get subrole: \(error.localizedDescription)", category: .window)
            return nil
        }
    }

    var title: String? {
        do {
            return try axWindow.getValue(.title)
        } catch {
            Log.error("Failed to get title: \(error.localizedDescription)", category: .window)
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
                Log.error("Failed to get enhancedUserInterface: \(error.localizedDescription)", category: .window)
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
                Log.error("Failed to set enhancedUserInterface: \(error.localizedDescription)", category: .window)
            }
        }
    }

    /// Focus the window.
    @MainActor
    func focus() {
        // First activate the application to ensure proper window management context
        if let runningApplication = nsRunningApplication {
            runningApplication.activate(options: .activateIgnoringOtherApps)
        }

        try? axWindow.performAction(.raise)

        /// See:  https://github.com/yresk/alt-tab-macos/blob/5b8a9110dbdb9b4802a8a85ee1469427fbc192e8/alt-tab-macos/api-wrappers/AXUIElement.swift#L60
        if let pid = try? axWindow.getPID() {
            _ = SkyLightToolBelt.makeKeyWindow(
                windowID: cgWindowID,
                pid: pid
            )

            _ = SkyLightToolBelt.makeFrontProcess(
                windowID: cgWindowID,
                pid: pid
            )

            _ = SkyLightToolBelt.makeKeyWindow(
                windowID: cgWindowID,
                pid: pid
            )
        }

        try? axWindow.performAction(.raise)
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
                Log.error("Failed to get fullscreen: \(error.localizedDescription)", category: .window)
                return false
            }
        }
        set {
            do {
                try axWindow.setValue(.fullScreen, value: newValue)
            } catch {
                Log.error("Failed to set fullscreen: \(error.localizedDescription)", category: .window)
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
                Log.error("Failed to get minimized: \(error.localizedDescription)", category: .window)
                return false
            }
        }
        set {
            do {
                try axWindow.setValue(.minimized, value: newValue)
            } catch {
                Log.error("Failed to set minimized: \(error.localizedDescription)", category: .window)
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
                Log.error("Failed to get position: \(error.localizedDescription)", category: .window)
                return .zero
            }
        }
        set {
            do {
                try axWindow.setValue(.position, value: newValue)
            } catch {
                Log.error("Failed to set position: \(error.localizedDescription)", category: .window)
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
                Log.error("Failed to get size: \(error.localizedDescription)", category: .window)
                return .zero
            }
        }
        set {
            do {
                try axWindow.setValue(.size, value: newValue)
            } catch {
                Log.error("Failed to set size: \(error.localizedDescription)", category: .window)
            }
        }
    }

    var isResizable: Bool {
        do {
            let result: Bool = try axWindow.canSetValue(.size)
            return result
        } catch {
            Log.error("Failed to determine if window size can be set: \(error.localizedDescription)", category: .window)
            return true
        }
    }

    var frame: CGRect {
        CGRect(origin: position, size: size)
    }

    func setFrame(
        _ rect: CGRect,
        sizeFirst: Bool = false
    ) {
        let enhancedUI = enhancedUserInterface

        if enhancedUI {
            let appName = nsRunningApplication?.localizedName
            Log.info("\(appName ?? "This app")'s enhanced UI will be temporarily disabled while resizing.", category: .window)
            enhancedUserInterface = false
        }

        if sizeFirst {
            size = rect.size
        }
        position = rect.origin
        size = rect.size

        if enhancedUI {
            enhancedUserInterface = true
        }
    }

    func setFrameAnimated(
        _ rect: CGRect,
        bounds: CGRect
    ) async throws {
        let enhancedUI = enhancedUserInterface

        if enhancedUI {
            let appName = nsRunningApplication?.localizedName
            Log.info("\(appName ?? "This app")'s enhanced UI will be temporarily disabled while resizing.", category: .window)
            enhancedUserInterface = false
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(), Error>) in
            Task {
                try Task.checkCancellation()
                let animation = WindowTransformAnimation(
                    rect,
                    window: self,
                    bounds: bounds
                ) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
                await animation.start()
            }
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
