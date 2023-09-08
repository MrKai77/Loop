//
//  AXUIElement+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-16.
//

import SwiftUI

extension AXUIElement {
    static let systemWide = AXUIElementCreateSystemWide()

    func getValue(_ attribute: NSAccessibility.Attribute) -> AnyObject? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(self, attribute as CFString, &value)
        if result == .success {
            return value
        }
        return nil
    }

    @discardableResult
    func setValue(_ attribute: NSAccessibility.Attribute, value: AnyObject) -> Bool {
        let result = AXUIElementSetAttributeValue(self, attribute as CFString, value)
        return result == .success
    }

    @discardableResult
    func setValue(_ attribute: NSAccessibility.Attribute, value: Bool) -> Bool {
        return setValue(attribute, value: value as CFBoolean)
    }

    @discardableResult
    func setValue(_ attribute: NSAccessibility.Attribute, value: CGPoint) -> Bool {
        guard let axValue = AXValue.from(value: value, type: .cgPoint) else { return false }
        return self.setValue(attribute, value: axValue)
    }

    @discardableResult
    func setValue(_ attribute: NSAccessibility.Attribute, value: CGSize) -> Bool {
        guard let axValue = AXValue.from(value: value, type: .cgSize) else { return false }
        return self.setValue(attribute, value: axValue)
    }

    func performAction(_ action: String) {
        AXUIElementPerformAction(self, action as CFString)
    }

    func getElementAtPosition(_ position: CGPoint) -> AXUIElement? {
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(self, Float(position.x), Float(position.y), &element)
        guard result == .success else { return nil }
        return element
    }

    // Only used when experimenting
    func getAttributeNames() -> [String]? {
        var ref: CFArray?
        let error = AXUIElementCopyAttributeNames(self, &ref)
        if error == .success {
            return ref! as [AnyObject] as? [String]
        }
        return nil
    }
}

extension NSAccessibility.Attribute {
    static let fullScreen: NSAccessibility.Attribute = NSAccessibility.Attribute(rawValue: "AXFullScreen")
}

extension AXValue {
    static func from(value: Any, type: AXValueType) -> AXValue? {
        var value = value
        return AXValueCreate(type, &value)
    }
}
