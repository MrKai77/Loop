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
    static var maskLeftShift: CGEventFlags { CGEventFlags(rawValue: UInt64(NX_DEVICELSHIFTKEYMASK)) }
    static var maskLeftControl: CGEventFlags { CGEventFlags(rawValue: UInt64(NX_DEVICELCTLKEYMASK)) }
    static var maskLeftAlternate: CGEventFlags { CGEventFlags(rawValue: UInt64(NX_DEVICELALTKEYMASK)) }
    static var maskLeftCommand: CGEventFlags { CGEventFlags(rawValue: UInt64(NX_DEVICELCMDKEYMASK)) }

    static var maskRightControl: CGEventFlags { CGEventFlags(rawValue: UInt64(NX_DEVICERCTLKEYMASK)) }
    static var maskRightShift: CGEventFlags { CGEventFlags(rawValue: UInt64(NX_DEVICERSHIFTKEYMASK)) }
    static var maskRightAlternate: CGEventFlags { CGEventFlags(rawValue: UInt64(NX_DEVICERALTKEYMASK)) }
    static var maskRightCommand: CGEventFlags { CGEventFlags(rawValue: UInt64(NX_DEVICERCMDKEYMASK)) }

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

        return result
    }
}
