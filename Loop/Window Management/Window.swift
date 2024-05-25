//
//  Window.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-01.
//

import SwiftUI
import Defaults

@_silgen_name("_AXUIElementGetWindow") @discardableResult
func _AXUIElementGetWindow(_ axUiElement: AXUIElement, _ wid: inout CGWindowID) -> AXError

class Window {
    let axWindow: AXUIElement
    let cgWindowID: CGWindowID
    let nsRunningApplication: NSRunningApplication?

    init?(element: AXUIElement) {
        self.axWindow = element

        var pid = pid_t(0)
        _ = AXUIElementGetPid(self.axWindow, &pid)

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
        guard let window = element.getValue(.focusedWindow) else { return nil }
        // swiftlint:disable force_cast
        self.init(element: window as! AXUIElement)
        // swiftlint:enable force_cast
    }

    func getPid() -> pid_t? {
        var pid = pid_t(0)
        let result = AXUIElementGetPid(self.axWindow, &pid)
        guard result == .success else { return nil }
        return pid
    }

    var role: NSAccessibility.Role? {
        guard let value = self.axWindow.getValue(.role) as? String else { return nil }
        return NSAccessibility.Role(rawValue: value)
    }

    var subrole: NSAccessibility.Subrole? {
        guard let value = self.axWindow.getValue(.subrole) as? String else { return nil }
        return NSAccessibility.Subrole(rawValue: value)
    }

    var title: String? {
        return self.axWindow.getValue(.title) as? String
    }

    var enhancedUserInterface: Bool? {
        get {
            guard let pid = self.getPid() else { return nil }
            let appWindow = AXUIElementCreateApplication(pid)
            return appWindow.getValue(.enhancedUserInterface) as? Bool
        }
        set {
            guard
                let newValue = newValue,
                let pid = self.getPid()
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
        let result = self.axWindow.getValue(.fullScreen) as? NSNumber
        return result?.boolValue ?? false
    }
    @discardableResult
    func setFullscreen(_ state: Bool) -> Bool {
        return self.axWindow.setValue(.fullScreen, value: state)
    }
    @discardableResult
    func toggleFullscreen() -> Bool {
        if !self.isFullscreen {
            return self.setFullscreen(true)
        }
        return self.setHidden(false)
    }

    var isHidden: Bool {
        return self.nsRunningApplication?.isHidden ?? false
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
        let result = self.axWindow.getValue(.minimized) as? NSNumber
        return result?.boolValue ?? false
    }
    @discardableResult
    func setMinimized(_ state: Bool) -> Bool {
        return self.axWindow.setValue(.minimized, value: state)
    }
    @discardableResult
    func toggleMinimized() -> Bool {
        if !self.isMinimized {
            return self.setMinimized(true)
        }
        return self.setMinimized(false)
    }

    var position: CGPoint {
        var point: CGPoint = .zero
        guard let value = self.axWindow.getValue(.position) else { return point }
        // swiftlint:disable force_cast
        AXValueGetValue(value as! AXValue, .cgPoint, &point)    // Convert to CGPoint
        // swiftlint:enable force_cast
        return point
    }
    @discardableResult
    func setPosition(_ position: CGPoint) -> Bool {
        return self.axWindow.setValue(.position, value: position)
    }

    var size: CGSize {
        var size: CGSize = .zero
        guard let value = self.axWindow.getValue(.size) else { return size }
        // swiftlint:disable force_cast
        AXValueGetValue(value as! AXValue, .cgSize, &size)      // Convert to CGSize
        // swiftlint:enable force_cast
        return size
    }
    @discardableResult
    func setSize(_ size: CGSize) -> Bool {
        return self.axWindow.setValue(.size, value: size)
    }

    var frame: CGRect {
        return CGRect(origin: self.position, size: self.size)
    }

    func setFrame(
        _ rect: CGRect,
        animate: Bool = false,
        sizeFirst: Bool = false, // Only does something when window animations are off
        bounds: CGRect = .zero, // Only does something when window animations are on
        completionHandler: @escaping (() -> Void) = {}
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
