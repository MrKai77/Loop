//
//  AXUIElement+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-16.
//

import SwiftUI

extension AXUIElement {
    static let systemWide = AXUIElementCreateSystemWide()

    func getValue<T>(_ attribute: NSAccessibility.Attribute) -> T? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(self, attribute as CFString, &value)
        
        if result == .noValue || result == .attributeUnsupported {
            return nil
        }

        guard result == .success else {
            return nil
        }

        guard let unpackedValue = (unpackAXValue(value!) as? T) else {
            return nil
        }

        return unpackedValue
    }

    @discardableResult
    func setValue(_ attribute: NSAccessibility.Attribute, value: Any) -> Bool {
        let result = AXUIElementSetAttributeValue(self, attribute as CFString, packAXValue(value))
        return result == .success
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

    private func packAXValue(_ value: Any) -> AnyObject {
        switch value {
        case let val as Window:
            return val.axWindow
        case let val as Bool:
            return val as CFBoolean
        case var val as CFRange:
            return AXValueCreate(AXValueType(rawValue: kAXValueCFRangeType)!, &val)!
        case var val as CGPoint:
            return AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!, &val)!
        case var val as CGRect:
            return AXValueCreate(AXValueType(rawValue: kAXValueCGRectType)!, &val)!
        case var val as CGSize:
            return AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!, &val)!
        default:
            return value as AnyObject
        }
    }

    private func unpackAXValue(_ value: AnyObject) -> Any {
        switch CFGetTypeID(value) {
        case AXUIElementGetTypeID():
            return value as! AXUIElement
        case AXValueGetTypeID():
            let type = AXValueGetType(value as! AXValue)
            switch type {
            case .axError:
                var result: AXError = .success
                let success = AXValueGetValue(value as! AXValue, type, &result)
                assert(success)
                return result
            case .cfRange:
                var result: CFRange = CFRange()
                let success = AXValueGetValue(value as! AXValue, type, &result)
                assert(success)
                return result
            case .cgPoint:
                var result: CGPoint = CGPoint.zero
                let success = AXValueGetValue(value as! AXValue, type, &result)
                assert(success)
                return result
            case .cgRect:
                var result: CGRect = CGRect.zero
                let success = AXValueGetValue(value as! AXValue, type, &result)
                assert(success)
                return result
            case .cgSize:
                var result: CGSize = CGSize.zero
                let success = AXValueGetValue(value as! AXValue, type, &result)
                assert(success)
                return result
            default:
                return value
            }
        default:
            return value
        }
    }

    func getPID() -> pid_t? {
        var pid: pid_t = 0
        let result = AXUIElementGetPid(self, &pid)

        guard result == .success else {
            return nil
        }

        return pid
    }
}

extension NSAccessibility.Attribute {
    static let fullScreen: NSAccessibility.Attribute = .init(rawValue: "AXFullScreen")
    static let enhancedUserInterface = NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface")
    static let windowIds = NSAccessibility.Attribute(rawValue: "AXWindowsIDs")
}
