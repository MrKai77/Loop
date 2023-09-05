//
//  AXUIElement+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-16.
//

import SwiftUI

extension AXUIElement {
    func getValue(attribute: String) -> CFTypeRef? {
        var ref: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(self, attribute as CFString, &ref)
        if error == .success {
            return ref
        }
        return .none
    }

    func setValue(attribute: String, value: CFTypeRef) -> Bool {
        let error = AXUIElementSetAttributeValue(self, attribute as CFString, value)
        return error == .success
    }

    func performAction(_ action: String) {
        AXUIElementPerformAction(self, action as CFString)
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

    func getElementAtPosition(_ position: CGPoint) -> AXUIElement? {
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(self, Float(position.x), Float(position.y), &element)
        guard result == .success else { return nil }
        return element
    }
}
