//
//  Window.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-01.
//

import Defaults
import SwiftUI

@_silgen_name("_AXUIElementGetWindow") @discardableResult
func _AXUIElementGetWindow(_ axUiElement: AXUIElement, _ wid: inout CGWindowID) -> AXError

enum WindowError: Error {
    case invalidWindow

    var localizedDescription: String {
        switch self {
        case .invalidWindow:
            "Invalid window"
        }
    }
}

class Window {
    let axWindow: AXUIElement
    let cgWindowID: CGWindowID
    let nsRunningApplication: NSRunningApplication?

    var observer: Observer?

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

    deinit {
        if let observer = self.observer {
            observer.stop()
        }
    }

    var role: NSAccessibility.Role? {
        do {
            guard let value: String = try self.axWindow.getValue(.role) else {
                return nil
            }
            return NSAccessibility.Role(rawValue: value)
        } catch {
            print("Failed to get role: \(error.localizedDescription)")
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
            print("Failed to get subrole: \(error.localizedDescription)")
            return nil
        }
    }

    var title: String? {
        do {
            return try self.axWindow.getValue(.title)
        } catch {
            print("Failed to get title: \(error.localizedDescription)")
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
                print("Failed to get enhancedUserInterface: \(error.localizedDescription)")
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
                print("Failed to set enhancedUserInterface: \(error.localizedDescription)")
            }
        }
    }

    /// Activate the window. This will bring it to the front and focus it if possible
    func activate() {
        do {
            try self.axWindow.setValue(.main, value: true)
            if let runningApplication = self.nsRunningApplication {
                runningApplication.activate()
            }
        } catch {
            print("Failed to activate window: \(error.localizedDescription)")
        }
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
                print("Failed to get fullscreen: \(error.localizedDescription)")
                return false
            }
        }
        set {
            do {
                try self.axWindow.setValue(.fullScreen, value: newValue)
            } catch {
                print("Failed to set fullscreen: \(error.localizedDescription)")
            }
        }
    }

    func toggleFullscreen() {
        fullscreen = !fullscreen
    }

    var isHidden: Bool {
        self.nsRunningApplication?.isHidden ?? false
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
        if !self.isHidden {
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
                print("Failed to get minimized: \(error.localizedDescription)")
                return false
            }
        }
        set {
            do {
                try self.axWindow.setValue(.minimized, value: newValue)
            } catch {
                print("Failed to set minimized: \(error.localizedDescription)")
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
                print("Failed to get position: \(error.localizedDescription)")
                return .zero
            }
        }
        set {
            do {
                try self.axWindow.setValue(.position, value: newValue)
            } catch {
                print("Failed to set position: \(error.localizedDescription)")
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
                print("Failed to get size: \(error.localizedDescription)")
                return .zero
            }
        }
        set {
            do {
                try self.axWindow.setValue(.size, value: newValue)
            } catch {
                print("Failed to set size: \(error.localizedDescription)")
            }
        }
    }

    var isResizable: Bool {
        do {
            let result: Bool = try self.axWindow.canSetValue(.size)
            return result
        } catch {
            print("Failed to determine if window size can be set: \(error.localizedDescription)")
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
            print("\(appName ?? "This app")'s enhanced UI will be temporarily disabled while resizing.")
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

    public func createObserver(_ callback: @escaping Observer.Callback) -> Observer? {
        do {
            return try Observer(processID: self.axWindow.getPID()!, callback: callback)
        } catch AXError.invalidUIElement {
            return nil
        } catch {
            fatalError("Caught unexpected error creating observer: \(error)")
        }
    }

    public func createObserver(_ callback: @escaping Observer.CallbackWithInfo) -> Observer? {
        do {
            return try Observer(processID: self.axWindow.getPID()!, callback: callback)
        } catch AXError.invalidUIElement {
            return nil
        } catch {
            fatalError("Caught unexpected error creating observer: \(error)")
        }
    }
}
