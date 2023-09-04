//
//  Window.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-01.
//

import SwiftUI

class Window {
    private let kAXFullscreenAttribute = "AXFullScreen"
    let axWindow: AXUIElement

    init?(window: AXUIElement) {
        self.axWindow = window

        if role != kAXWindowRole,
           subrole != kAXStandardWindowSubrole {
            return nil
        }
    }

    convenience init?(pid: pid_t) {
        let element = AXUIElementCreateApplication(pid)
        guard let window = element.getValue(attribute: kAXFocusedWindowAttribute) else { return nil }
        // swiftlint:disable force_cast
        self.init(window: window as! AXUIElement)
        // swiftlint:enable force_cast
    }

    var role: String? {
        return self.axWindow.getValue(attribute: kAXRoleAttribute) as? String
    }

    var subrole: String? {
        return self.axWindow.getValue(attribute: kAXSubroleAttribute) as? String
    }

    var isFullscreen: Bool {
        let result = self.axWindow.getValue(attribute: kAXFullscreenAttribute) as? NSNumber
        return result?.boolValue ?? false
    }
    @discardableResult
    func setFullscreen(_ state: Bool) -> Bool {
        return self.axWindow.setValue(
            attribute: kAXFullscreenAttribute,
            value: state ? kCFBooleanTrue : kCFBooleanFalse
        )
    }

    var isMinimized: Bool {
        let result = self.axWindow.getValue(attribute: kAXMinimizedAttribute) as? NSNumber
        return result?.boolValue ?? false
    }
    @discardableResult
    func setMinimized(_ state: Bool) -> Bool {
        return self.axWindow.setValue(
            attribute: kAXMinimizedAttribute,
            value: state ? kCFBooleanTrue : kCFBooleanFalse
        )
    }

    var origin: CGPoint {
        var point: CGPoint = .zero
        guard let value = self.axWindow.getValue(attribute: kAXPositionAttribute) else { return point }
        // swiftlint:disable force_cast
        AXValueGetValue(value as! AXValue, .cgPoint, &point)    // Convert to CGPoint
        // swiftlint:enable force_cast
        return point
    }
    @discardableResult
    func setOrigin(_ origin: CGPoint) -> Bool {
        var position = origin
        if let value = AXValueCreate(AXValueType.cgPoint, &position) {
            return self.axWindow.setValue(attribute: kAXPositionAttribute, value: value)
        }
        return false
    }

    var size: CGSize {
        var size: CGSize = .zero
        guard let value = self.axWindow.getValue(attribute: kAXSizeAttribute) else { return size }
        // swiftlint:disable force_cast
        AXValueGetValue(value as! AXValue, .cgSize, &size)      // Convert to CGSize
        // swiftlint:enable force_cast
        return size
    }
    @discardableResult
    func setSize(_ size: CGSize) -> Bool {
        var size = size
        if let value = AXValueCreate(AXValueType.cgSize, &size) {
            return self.axWindow.setValue(attribute: kAXSizeAttribute, value: value)
        }
        return false
    }

    var frame: CGRect {
        return CGRect(origin: self.origin, size: self.size)
    }

    func setFrame(_ rect: CGRect, animate: Bool = false) {
        if animate {
            let animation = WindowTransformAnimation(rect, window: self)
            animation.startInBackground()
        } else {
            self.setOrigin(rect.origin)
            self.setSize(rect.size)
        }
    }

    /// MacOS doesn't provide us a way to find the minimum size of a window from the accessibility API.
    /// So we deliberately force-resize the window to 0x0 and see how small it goes, take note of the frame,
    /// then we resotere the original window size. However, this does have one big consequence. The user
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
