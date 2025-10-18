//
//  Window.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-01.
//

import Defaults
import OSLog
import SwiftUI

@_silgen_name("_AXUIElementGetWindow") @discardableResult
func _AXUIElementGetWindow(_ axUiElement: AXUIElement, _ wid: inout CGWindowID) -> AXError

@_silgen_name("GetProcessForPID") @discardableResult
func GetProcessForPID(_ pid: pid_t, _ psn: inout ProcessSerialNumber) -> OSStatus

@_silgen_name("_SLPSSetFrontProcessWithOptions") @discardableResult
func _SLPSSetFrontProcessWithOptions(_ psn: inout ProcessSerialNumber, _ wid: UInt32, _ mode: UInt32) -> CGError

@_silgen_name("SLPSPostEventRecordTo") @discardableResult
func SLPSPostEventRecordTo(_ psn: inout ProcessSerialNumber, _ bytes: inout UInt8) -> CGError

let kCPSUserGenerated: UInt32 = 0x200

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

        if self.role != .window,
           self.subrole != .standardWindow {
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
            guard let value: String = try self.axWindow.getValue(.role) else {
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
            guard let value: String = try self.axWindow.getValue(.subrole) else {
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
            return try self.axWindow.getValue(.title)
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
        if let runningApplication = self.nsRunningApplication {
            runningApplication.activate(options: .activateIgnoringOtherApps)
        }

        // Then set the window as main after a brief delay to ensure proper ordering
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            try? self.axWindow.setValue(.main, value: true)
        }

        focus()
    }

    ///
    /// Focuses the window. This will attempt to bring the window to the front and make it the active window.
    /// Note that this first sets the process as frontmost, *then* sends a left click event to the window itself.
    ///
    /// - Returns:
    /// `true` if the window was successfully focused; `false` otherwise.
    ///
    /// - Description:
    /// This method uses a private API to focus the window.
    /// The code for this method is derived from the Amethyst source code. Details of its implementation can be found [here](https://github.com/Hammerspoon/hammerspoon/issues/370#issuecomment-545545468)
    @discardableResult
    private func focus() -> Bool {
        guard let pid = try? axWindow.getPID() else { return false }

        var wid = cgWindowID
        var psn = ProcessSerialNumber()
        let status = GetProcessForPID(pid, &psn)

        guard status == noErr else {
            return false
        }

        var cgStatus = _SLPSSetFrontProcessWithOptions(&psn, wid, kCPSUserGenerated)

        guard cgStatus == .success else {
            return false
        }

        /// `0x01` is left click down, `0x02` is left click up (see `CGEventType`)
        for byte in [0x01, 0x02] {
            /// Create raw `SLSEvent` data.
            /// Future consideration: instead of manually creating the bytes here, investigate:
            /// - Creating a `SLSEvent` (likely analogous to `CGEvent`)
            /// - Apply an identifier to the event to help Loop differentiate events that originate from itself
            /// - Converting the `SLSEvent` to data using `SLEventCreateData` in SkyLight
            var bytes = [UInt8](repeating: 0, count: 0xF8)
            bytes[0x04] = 0xF8
            bytes[0x08] = UInt8(byte)
            bytes[0x3A] = 0x10
            memcpy(&bytes[0x3C], &wid, MemoryLayout<UInt32>.size)
            memset(&bytes[0x20], 0xFF, 0x10)
            cgStatus = bytes.withUnsafeMutableBufferPointer { pointer in
                SLPSPostEventRecordTo(&psn, &pointer.baseAddress!.pointee)
            }
            guard cgStatus == .success else {
                return false
            }
        }

        return true
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
                let result: NSNumber? = try self.axWindow.getValue(.fullScreen)
                return result?.boolValue ?? false
            } catch {
                logger.error("Failed to get fullscreen: \(error.localizedDescription)")
                return false
            }
        }
        set {
            do {
                try self.axWindow.setValue(.fullScreen, value: newValue)
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
        self.nsRunningApplication?.isHidden ?? false
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
            result = self.nsRunningApplication?.hide() ?? false
        } else {
            result = self.nsRunningApplication?.unhide() ?? false
        }
        return result
    }

    @discardableResult
    func toggleHidden() -> Bool {
        if !self.isApplicationHidden {
            return self.setHidden(true)
        }
        return self.setHidden(false)
    }

    var minimized: Bool {
        get {
            do {
                let result: NSNumber? = try self.axWindow.getValue(.minimized)
                return result?.boolValue ?? false
            } catch {
                logger.error("Failed to get minimized: \(error.localizedDescription)")
                return false
            }
        }
        set {
            do {
                try self.axWindow.setValue(.minimized, value: newValue)
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
                guard let result: CGPoint = try self.axWindow.getValue(.position) else {
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
                try self.axWindow.setValue(.position, value: newValue)
            } catch {
                logger.error("Failed to set position: \(error.localizedDescription)")
            }
        }
    }

    var size: CGSize {
        get {
            do {
                guard let result: CGSize = try self.axWindow.getValue(.size) else {
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
                try self.axWindow.setValue(.size, value: newValue)
            } catch {
                logger.error("Failed to set size: \(error.localizedDescription)")
            }
        }
    }

    var isResizable: Bool {
        do {
            let result: Bool = try self.axWindow.canSetValue(.size)
            return result
        } catch {
            logger.error("Failed to determine if window size can be set: \(error.localizedDescription)")
            return true
        }
    }

    var frame: CGRect {
        CGRect(origin: self.position, size: self.size)
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
        let enhancedUI = self.enhancedUserInterface

        if enhancedUI {
            let appName = nsRunningApplication?.localizedName
            logger.info("\(appName ?? "This app")'s enhanced UI will be temporarily disabled while resizing.")
            self.enhancedUserInterface = false
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
                self.size = rect.size
            }
            self.position = rect.origin
            self.size = rect.size

            completionHandler()
        }

        if enhancedUI {
            self.enhancedUserInterface = true
        }
    }
}

extension Window: CustomDebugStringConvertible {
    var debugDescription: String {
        let name = nsRunningApplication?.localizedName ?? title ?? "<unknown>"
        return "Window(id: \(cgWindowID), title: \(name))"
    }
}
