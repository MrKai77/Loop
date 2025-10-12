//
//  AXUIElement+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-16.
//

import SwiftUI

extension AXUIElement {
    static let systemWide = AXUIElementCreateSystemWide()

    func getValue<T>(_ attribute: NSAccessibility.Attribute) throws -> T? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(self, attribute as CFString, &value)

        if error == .noValue || error == .attributeUnsupported {
            return nil
        }

        guard error == .success else {
            throw error
        }

        guard let unpackedValue = (unpackAXValue(value!) as? T) else {
            throw AXError.illegalArgument
        }

        return unpackedValue
    }

    func setValue(_ attribute: NSAccessibility.Attribute, value: Any) throws {
        let error = AXUIElementSetAttributeValue(self, attribute as CFString, packAXValue(value))

        guard error == .success else {
            throw error
        }
    }

    func canSetValue(_ attribute: NSAccessibility.Attribute) throws -> Bool {
        var isSettable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(self, attribute as CFString, &isSettable)
        guard error == .success else {
            throw error
        }
        return isSettable.boolValue
    }

    func getElementAtPosition(_ position: CGPoint) throws -> AXUIElement? {
        var element: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(self, Float(position.x), Float(position.y), &element)

        guard error == .success else {
            throw error
        }

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
            val.axWindow
        case let val as Bool:
            val as CFBoolean
        case var val as CFRange:
            AXValueCreate(AXValueType(rawValue: kAXValueCFRangeType)!, &val)!
        case var val as CGPoint:
            AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!, &val)!
        case var val as CGRect:
            AXValueCreate(AXValueType(rawValue: kAXValueCGRectType)!, &val)!
        case var val as CGSize:
            AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!, &val)!
        default:
            value as AnyObject
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
                var result = CFRange()
                let success = AXValueGetValue(value as! AXValue, type, &result)
                assert(success)
                return result
            case .cgPoint:
                var result = CGPoint.zero
                let success = AXValueGetValue(value as! AXValue, type, &result)
                assert(success)
                return result
            case .cgRect:
                var result = CGRect.zero
                let success = AXValueGetValue(value as! AXValue, type, &result)
                assert(success)
                return result
            case .cgSize:
                var result = CGSize.zero
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

    func getPID() throws -> pid_t? {
        var pid: pid_t = 0
        let error = AXUIElementGetPid(self, &pid)

        guard error == .success else {
            throw error
        }

        return pid
    }

    func getWindowID() throws -> CGWindowID {
        var id: CGWindowID = 0
        let error = _AXUIElementGetWindow(self, &id)

        guard error == .success else {
            throw error
        }

        return id
    }

    func performAction(_ action: NSAccessibility.Action) throws {
        let error = AXUIElementPerformAction(self, action as CFString)

        guard error == .success else {
            throw error
        }
    }

    var children: [AXUIElement] {
        let children: [AXUIElement]? = try? getValue(.children)
        return children ?? []
    }
}

extension AXError: @retroactive _BridgedNSError {}
extension AXError: @retroactive _ObjectiveCBridgeableError {}
extension AXError: Swift.Error {}

extension NSAccessibility.Attribute {
    static let fullScreen: NSAccessibility.Attribute = .init(rawValue: "AXFullScreen")
    static let enhancedUserInterface = NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface")
    static let windowIds = NSAccessibility.Attribute(rawValue: "AXWindowsIDs")
}
