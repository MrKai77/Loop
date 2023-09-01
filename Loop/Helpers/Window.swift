//
//  Window.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-01.
//

import SwiftUI

class Window {
    private let kAXFullscreenAttribute = "AXFullScreen"
    let window: AXUIElement

    init?(window: AXUIElement) {
        self.window = window

        if role != kAXWindowRole,
           subrole != kAXStandardWindowSubrole {
            return nil
        }
    }

    convenience init?(pid: pid_t) {
        let element = AXUIElementCreateApplication(pid)
        guard let window = element.copyAttributeValue(attribute: kAXFocusedWindowAttribute) else { return nil }
        // swiftlint:disable force_cast
        self.init(window: window as! AXUIElement)
        // swiftlint:enable force_cast
    }

    var role: String? {
        return self.window.copyAttributeValue(attribute: kAXRoleAttribute) as? String
    }

    var subrole: String? {
        return self.window.copyAttributeValue(attribute: kAXSubroleAttribute) as? String
    }

    var isFullscreen: Bool {
        let result = self.window.copyAttributeValue(attribute: kAXFullscreenAttribute) as? NSNumber
        return result?.boolValue ?? false
    }
    @discardableResult
    func setFullscreen(_ state: Bool) -> Bool {
        return self.window.setAttributeValue(
            attribute: kAXFullscreenAttribute,
            value: state ? kCFBooleanTrue : kCFBooleanFalse
        )
    }

    var isMinimized: Bool {
        let result = self.window.copyAttributeValue(attribute: kAXMinimizedAttribute) as? NSNumber
        return result?.boolValue ?? false
    }
    @discardableResult
    func setMinimized(_ state: Bool) -> Bool {
        return self.window.setAttributeValue(
            attribute: kAXMinimizedAttribute,
            value: state ? kCFBooleanTrue : kCFBooleanFalse
        )
    }

    var origin: CGPoint {
        var point: CGPoint = .zero
        guard let value = self.window.copyAttributeValue(attribute: kAXPositionAttribute) else { return point }
        // swiftlint:disable force_cast
        AXValueGetValue(value as! AXValue, .cgPoint, &point)    // Convert to CGPoint
        // swiftlint:enable force_cast
        return point
    }
    @discardableResult
    func setOrigin(_ origin: CGPoint) -> Bool {
        var position = origin
        if let value = AXValueCreate(AXValueType.cgPoint, &position) {
            return self.window.setAttributeValue(attribute: kAXPositionAttribute, value: value)
        }
        return false
    }

    var size: CGSize {
        var size: CGSize = .zero
        guard let value = self.window.copyAttributeValue(attribute: kAXSizeAttribute) else { return size }
        // swiftlint:disable force_cast
        AXValueGetValue(value as! AXValue, .cgSize, &size)      // Convert to CGSize
        // swiftlint:enable force_cast
        return size
    }
    @discardableResult
    func setSize(_ size: CGSize) -> Bool {
        var size = size
        if let value = AXValueCreate(AXValueType.cgSize, &size) {
            return self.window.setAttributeValue(attribute: kAXSizeAttribute, value: value)
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
