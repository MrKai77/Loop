//
//  AXUIElement+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-16.
//

import SwiftUI

extension AXUIElement {
    func setAttributeValue(attribute: String, value: CFTypeRef) -> Bool {
        let error = AXUIElementSetAttributeValue(self, attribute as CFString, value)
        return error == .success
    }

    func copyAttributeValue(attribute: String) -> CFTypeRef? {
        var ref: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(self, attribute as CFString, &ref)
        if error == .success {
            return ref
        }
        return .none
    }

    func getAttributeNames() -> [String]? {
        var ref: CFArray?
        let error = AXUIElementCopyAttributeNames(self, &ref)
        if error == .success {
            return ref! as [AnyObject] as? [String]
        }
        return nil
    }
}
