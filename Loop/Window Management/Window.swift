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

class Window {
    let axWindow: AXUIElement
    let cgWindowID: CGWindowID
    let nsRunningApplication: NSRunningApplication?

    init?(element: AXUIElement) {
        self.axWindow = element

        let pid = axWindow.getPID()
        self.nsRunningApplication = NSWorkspace.shared.runningApplications.first {
            $0.processIdentifier == pid
        }

        // Set self's CGWindowID
        var windowId = CGWindowID(0)
        let result = _AXUIElementGetWindow(self.axWindow, &windowId)
        guard result == .success else { return nil }
        self.cgWindowID = windowId

        if self.role != .window,
           self.subrole != .standardWindow {
            print("This is an invalid window")
            return nil
        }

        // Check if this is a widget
        if let title = nsRunningApplication?.localizedName,
           title == "Notification Center" {
            print("This window is a part of Notification Center")
            return nil
        }
    }

    convenience init?(pid: pid_t) {
        let element = AXUIElementCreateApplication(pid)
        guard let window: AXUIElement = element.getValue(.focusedWindow) else {
            return nil
        }
        self.init(element: window)
    }

    var role: NSAccessibility.Role? {
        guard let value: String = self.axWindow.getValue(.role) else {
            return nil
        }
        return NSAccessibility.Role(rawValue: value)
    }

    var subrole: NSAccessibility.Subrole? {
        guard let value: String = self.axWindow.getValue(.subrole) else {
            return nil
        }
        return NSAccessibility.Subrole(rawValue: value)
    }

    var title: String? {
        self.axWindow.getValue(.title)
    }

    var enhancedUserInterface: Bool? {
        get {
            guard let pid = axWindow.getPID() else { return nil }
            let appWindow = AXUIElementCreateApplication(pid)
            return appWindow.getValue(.enhancedUserInterface)
        }
        set {
            guard 
                let newValue,
                let pid = axWindow.getPID()
            else {
                return
            }
            let appWindow = AXUIElementCreateApplication(pid)
            appWindow.setValue(.enhancedUserInterface, value: newValue)
        }
    }

    func activate() {
        self.axWindow.setValue(.main, value: true)
        if let runningApplication = self.nsRunningApplication {
            runningApplication.activate()
        }
    }

    var isAppExcluded: Bool {
        if let nsRunningApplication,
           let path = nsRunningApplication.bundleURL {
            return Defaults[.excludedApps].contains(path)
        }
        return false
    }

    var isFullscreen: Bool {
        let result: NSNumber? = self.axWindow.getValue(.fullScreen)
        return result?.boolValue ?? false
    }

    @discardableResult
    func setFullscreen(_ state: Bool) -> Bool {
        self.axWindow.setValue(.fullScreen, value: state)
    }

    @discardableResult
    func toggleFullscreen() -> Bool {
        if !self.isFullscreen {
            return self.setFullscreen(true)
        }
        return self.setHidden(false)
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

    var isMinimized: Bool {
        let result: NSNumber? = self.axWindow.getValue(.minimized)
        return result?.boolValue ?? false
    }

    @discardableResult
    func setMinimized(_ state: Bool) -> Bool {
        self.axWindow.setValue(.minimized, value: state)
    }

    @discardableResult
    func toggleMinimized() -> Bool {
        if !self.isMinimized {
            return self.setMinimized(true)
        }
        return self.setMinimized(false)
    }

    var position: CGPoint {
        guard let result: CGPoint = self.axWindow.getValue(.position) else {
            return .zero
        }
        return result
    }

    @discardableResult
    func setPosition(_ position: CGPoint) -> Bool {
        self.axWindow.setValue(.position, value: position)
    }

    var size: CGSize {
        guard let result: CGSize = self.axWindow.getValue(.size) else {
            return .zero
        }
        return result
    }

    @discardableResult
    func setSize(_ size: CGSize) -> Bool {
        self.axWindow.setValue(.size, value: size)
    }

    var frame: CGRect {
        CGRect(origin: self.position, size: self.size)
    }

    func setFrame(
        _ rect: CGRect,
        animate: Bool = false,
        sizeFirst: Bool = false, // Only does something when window animations are off
        bounds: CGRect = .zero, // Only does something when window animations are on
        completionHandler: @escaping (() -> ()) = {}
    ) {
        let enhancedUI = self.enhancedUserInterface ?? false

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
                self.setSize(rect.size)
            }
            self.setPosition(rect.origin)
            self.setSize(rect.size)

            completionHandler()
        }

        if enhancedUI {
            self.enhancedUserInterface = true
        }
    }
}
