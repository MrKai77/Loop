//
//  CGEventFlags+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-11.
//

// Huge thanks to @zenangst's "KeyCodes" repo for this extension!

import Carbon.HIToolbox
import Cocoa

extension CGEventFlags {
    static let maskLeftShift = CGEventFlags(rawValue: UInt64(NX_DEVICELSHIFTKEYMASK))
    static let maskLeftControl = CGEventFlags(rawValue: UInt64(NX_DEVICELCTLKEYMASK))
    static let maskLeftAlternate = CGEventFlags(rawValue: UInt64(NX_DEVICELALTKEYMASK))
    static let maskLeftCommand = CGEventFlags(rawValue: UInt64(NX_DEVICELCMDKEYMASK))

    static let maskRightControl = CGEventFlags(rawValue: UInt64(NX_DEVICERCTLKEYMASK))
    static let maskRightShift = CGEventFlags(rawValue: UInt64(NX_DEVICERSHIFTKEYMASK))
    static let maskRightAlternate = CGEventFlags(rawValue: UInt64(NX_DEVICERALTKEYMASK))
    static let maskRightCommand = CGEventFlags(rawValue: UInt64(NX_DEVICERCMDKEYMASK))

    static let maskFunction = CGEventFlags(rawValue: UInt64(NX_SECONDARYFNMASK))

    var keyCodes: Set<CGKeyCode> {
        var result: Set<CGKeyCode> = []

        if contains(.maskShift) || contains(.maskLeftShift) { result.insert(.kVK_Shift) }
        if contains(.maskRightShift) { result.insert(.kVK_RightShift) }

        if contains(.maskControl) || contains(.maskLeftControl) { result.insert(.kVK_Control) }
        if contains(.maskRightControl) { result.insert(.kVK_RightControl) }

        if contains(.maskAlternate) || contains(.maskLeftAlternate) { result.insert(.kVK_Option) }
        if contains(.maskRightAlternate) { result.insert(.kVK_RightOption) }

        if contains(.maskCommand) || contains(.maskLeftCommand) { result.insert(.kVK_Command) }
        if contains(.maskRightCommand) { result.insert(.kVK_RightCommand) }

        if contains(.maskSecondaryFn) { result.insert(.kVK_Function) }

        return result
    }
}
