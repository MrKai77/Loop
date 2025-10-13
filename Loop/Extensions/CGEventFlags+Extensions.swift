//
//  CGEventFlags+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-11.
//

import Carbon.HIToolbox
import Cocoa

extension CGEventFlags {
    init(cocoaFlags: NSEvent.ModifierFlags) {
        self.init(rawValue: UInt64(cocoaFlags.rawValue))
    }

    // Huge thanks to @zenangst's "KeyCodes" repo for these values!
    static let maskLeftShift = CGEventFlags(rawValue: UInt64(NX_DEVICELSHIFTKEYMASK))
    static let maskLeftControl = CGEventFlags(rawValue: UInt64(NX_DEVICELCTLKEYMASK))
    static let maskLeftAlternate = CGEventFlags(rawValue: UInt64(NX_DEVICELALTKEYMASK))
    static let maskLeftCommand = CGEventFlags(rawValue: UInt64(NX_DEVICELCMDKEYMASK))
    static let maskRightControl = CGEventFlags(rawValue: UInt64(NX_DEVICERCTLKEYMASK))
    static let maskRightShift = CGEventFlags(rawValue: UInt64(NX_DEVICERSHIFTKEYMASK))
    static let maskRightAlternate = CGEventFlags(rawValue: UInt64(NX_DEVICERALTKEYMASK))
    static let maskRightCommand = CGEventFlags(rawValue: UInt64(NX_DEVICERCMDKEYMASK))

    var keyCodes: Set<CGKeyCode> {
        var result: Set<CGKeyCode> = []

        if contains(.maskRightShift) { result.insert(.kVK_RightShift) }
        if contains(.maskLeftShift) { result.insert(.kVK_Shift) }
        if !result.contains(.kVK_Shift), !result.contains(.kVK_RightShift), contains(.maskShift) { result.insert(.kVK_Shift) }

        if contains(.maskRightControl) { result.insert(.kVK_RightControl) }
        if contains(.maskLeftControl) { result.insert(.kVK_Control) }
        if !result.contains(.kVK_Control), !result.contains(.kVK_RightControl), contains(.maskControl) { result.insert(.kVK_Control) }

        if contains(.maskRightAlternate) { result.insert(.kVK_RightOption) }
        if contains(.maskLeftAlternate) { result.insert(.kVK_Option) }
        if !result.contains(.kVK_Option), !result.contains(.kVK_RightOption), contains(.maskAlternate) { result.insert(.kVK_Option) }

        if contains(.maskRightCommand) { result.insert(.kVK_RightCommand) }
        if contains(.maskLeftCommand) { result.insert(.kVK_Command) }
        if !result.contains(.kVK_Command), !result.contains(.kVK_RightCommand), contains(.maskCommand) { result.insert(.kVK_Command) }

        if contains(.maskSecondaryFn) { result.insert(.kVK_Function) }

        return result
    }
}
