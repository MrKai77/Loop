//
//  Window.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-01.
//

import SwiftUI

class Window {
    let axWindow: AXUIElement
    let cgWindowID: CGWindowID
    var processID: pid_t

    init?(element: AXUIElement, pid: pid_t? = nil) {
        self.axWindow = element

        if pid == nil {
            self.processID = 0
            AXUIElementGetPid(self.axWindow, &processID)
        } else {
            self.processID = pid!
        }

        // Set self's CGWindowID
        var windowId = CGWindowID(0)
        let result = _AXUIElementGetWindow(self.axWindow, &windowId)
        guard result == .success else { return nil }
        self.cgWindowID = windowId

        if self.role != .window,
           self.subrole != .standardWindow {
            return nil
        }
    }

    convenience init?(pid: pid_t) {
        let element = AXUIElementCreateApplication(pid)
        guard let window = element.getValue(.focusedWindow) else { return nil }
        // swiftlint:disable force_cast
        self.init(element: window as! AXUIElement, pid: pid)
        // swiftlint:enable force_cast
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

    var isFullscreen: Bool {
        let result = self.axWindow.getValue(.fullScreen) as? NSNumber
        return result?.boolValue ?? false
    }
    @discardableResult
    func setFullscreen(_ state: Bool) -> Bool {
        return self.axWindow.setValue(.fullScreen, value: state)
    }

    var isMinimized: Bool {
        let result = self.axWindow.getValue(.minimized) as? NSNumber
        return result?.boolValue ?? false
    }
    @discardableResult
    func setMinimized(_ state: Bool) -> Bool {
        return self.axWindow.setValue(.minimized, value: state)
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

    func setFrame(_ rect: CGRect, animate: Bool = false, completionHandler: (() -> Void)? = nil) {
        if animate {
            let animation = WindowTransformAnimation(rect, window: self, completionHandler: completionHandler)
            animation.startInBackground()
        } else {
            self.setPosition(rect.origin)
            self.setSize(rect.size)

            if let completionHandler = completionHandler {
                completionHandler()
            }
        }
    }

    /// MacOS doesn't provide us a way to find the minimum size of a window from the accessibility API.
    /// So we deliberately force-resize the window to 0x0 and see how small it goes, take note of the frame,
    /// then we restore the original window size. However, this does have one big consequence. The user
    /// can see a single frame when the window is being resized to 0x0, then restored. So to counteract this,
    /// we take a screenshot of the screen, overlay it, and get the minimum size then close the overlay window.
    /// - Parameters:
    ///   - screen: The screen the window is on
    ///   - completion: What to do with the minimum size
    func getMinSize(screen: NSScreen, completion: @escaping (CGSize) -> Void) {
        // Take screenshot of screen
        guard let displayID = screen.displayID else { return }
        let imageRef = CGDisplayCreateImage(displayID)
        let image = NSImage(cgImage: imageRef!, size: .zero)

        // Initialize the overlay NSPanel
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.hasShadow = false
        panel.backgroundColor  = NSColor.white.withAlphaComponent(0.00001)
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.setFrame(screen.frame, display: false)
        panel.contentView = NSImageView(image: image)
        panel.orderFrontRegardless()

        var minSize: CGSize = .zero
        DispatchQueue.main.async {

            // Force-resize the window to 0x0
            let startingSize = self.size
            self.setSize(CGSize(width: 0, height: 0))

            // Take note of the minimum size
            minSize = self.size

            // Restore original window size
            self.setSize(startingSize)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.005) {
                // Close window, then activate completion handler
                panel.close()
                completion(minSize)
            }
        }
    }
}

@_silgen_name("_AXUIElementGetWindow") @discardableResult
func _AXUIElementGetWindow(_ axUiElement: AXUIElement, _ wid: inout CGWindowID) -> AXError
