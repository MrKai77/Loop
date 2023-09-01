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

    @discardableResult
    func setFrame(_ rect: CGRect) -> Bool {
        if self.setOrigin(rect.origin) && self.setSize(rect.size) {
            return true
        }
        return false
    }
}
