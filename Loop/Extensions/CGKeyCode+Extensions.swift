//
//  CGKeyCode+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-25.
//
// From https://gist.github.com/chrispaynter/07c9b16219c3d58f57a6e2b0249db4bf (but edited a lot)

import CoreGraphics
import Carbon
import SwiftUI

extension CGKeyCode {
    static let kVK_ANSI_A: CGKeyCode = 0x00
    static let kVK_ANSI_S: CGKeyCode = 0x01
    static let kVK_ANSI_D: CGKeyCode = 0x02
    static let kVK_ANSI_F: CGKeyCode = 0x03
    static let kVK_ANSI_H: CGKeyCode = 0x04
    static let kVK_ANSI_G: CGKeyCode = 0x05
    static let kVK_ANSI_Z: CGKeyCode = 0x06
    static let kVK_ANSI_X: CGKeyCode = 0x07
    static let kVK_ANSI_C: CGKeyCode = 0x08
    static let kVK_ANSI_V: CGKeyCode = 0x09
    static let kVK_ANSI_B: CGKeyCode = 0x0B
    static let kVK_ANSI_Q: CGKeyCode = 0x0C
    static let kVK_ANSI_W: CGKeyCode = 0x0D
    static let kVK_ANSI_E: CGKeyCode = 0x0E
    static let kVK_ANSI_R: CGKeyCode = 0x0F
    static let kVK_ANSI_Y: CGKeyCode = 0x10
    static let kVK_ANSI_T: CGKeyCode = 0x11
    static let kVK_ANSI_1: CGKeyCode = 0x12
    static let kVK_ANSI_2: CGKeyCode = 0x13
    static let kVK_ANSI_3: CGKeyCode = 0x14
    static let kVK_ANSI_4: CGKeyCode = 0x15
    static let kVK_ANSI_6: CGKeyCode = 0x16
    static let kVK_ANSI_5: CGKeyCode = 0x17
    static let kVK_ANSI_Equal: CGKeyCode = 0x18
    static let kVK_ANSI_9: CGKeyCode = 0x19
    static let kVK_ANSI_7: CGKeyCode = 0x1A
    static let kVK_ANSI_Minus: CGKeyCode = 0x1B
    static let kVK_ANSI_8: CGKeyCode = 0x1C
    static let kVK_ANSI_0: CGKeyCode = 0x1D
    static let kVK_ANSI_RightBracket: CGKeyCode = 0x1E
    static let kVK_ANSI_O: CGKeyCode = 0x1F
    static let kVK_ANSI_U: CGKeyCode = 0x20
    static let kVK_ANSI_LeftBracket: CGKeyCode = 0x21
    static let kVK_ANSI_I: CGKeyCode = 0x22
    static let kVK_ANSI_P: CGKeyCode = 0x23
    static let kVK_ANSI_L: CGKeyCode = 0x25
    static let kVK_ANSI_J: CGKeyCode = 0x26
    static let kVK_ANSI_Quote: CGKeyCode = 0x27
    static let kVK_ANSI_K: CGKeyCode = 0x28
    static let kVK_ANSI_Semicolon: CGKeyCode = 0x29
    static let kVK_ANSI_Backslash: CGKeyCode = 0x2A
    static let kVK_ANSI_Comma: CGKeyCode = 0x2B
    static let kVK_ANSI_Slash: CGKeyCode = 0x2C
    static let kVK_ANSI_N: CGKeyCode = 0x2D
    static let kVK_ANSI_M: CGKeyCode = 0x2E
    static let kVK_ANSI_Period: CGKeyCode = 0x2F
    static let kVK_ANSI_Grave: CGKeyCode = 0x32
    static let kVK_ANSI_KeypadDecimal: CGKeyCode = 0x41
    static let kVK_ANSI_KeypadMultiply: CGKeyCode = 0x43
    static let kVK_ANSI_KeypadPlus: CGKeyCode = 0x45
    static let kVK_ANSI_KeypadClear: CGKeyCode = 0x47
    static let kVK_ANSI_KeypadDivide: CGKeyCode = 0x4B
    static let kVK_ANSI_KeypadEnter: CGKeyCode = 0x4C
    static let kVK_ANSI_KeypadMinus: CGKeyCode = 0x4E
    static let kVK_ANSI_KeypadEquals: CGKeyCode = 0x51
    static let kVK_ANSI_Keypad0: CGKeyCode = 0x52
    static let kVK_ANSI_Keypad1: CGKeyCode = 0x53
    static let kVK_ANSI_Keypad2: CGKeyCode = 0x54
    static let kVK_ANSI_Keypad3: CGKeyCode = 0x55
    static let kVK_ANSI_Keypad4: CGKeyCode = 0x56
    static let kVK_ANSI_Keypad5: CGKeyCode = 0x57
    static let kVK_ANSI_Keypad6: CGKeyCode = 0x58
    static let kVK_ANSI_Keypad7: CGKeyCode = 0x59
    static let kVK_ANSI_Keypad8: CGKeyCode = 0x5B
    static let kVK_ANSI_Keypad9: CGKeyCode = 0x5C

    // keycodes for keys that are independent of keyboard layout
    static let kVK_Return: CGKeyCode = 0x24
    static let kVK_Tab: CGKeyCode = 0x30
    static let kVK_Space: CGKeyCode = 0x31
    static let kVK_Delete: CGKeyCode = 0x33
    static let kVK_Escape: CGKeyCode = 0x35
    static let kVK_Command: CGKeyCode = 0x37
    static let kVK_Shift: CGKeyCode = 0x38
    static let kVK_CapsLock: CGKeyCode = 0x39
    static let kVK_Option: CGKeyCode = 0x3A
    static let kVK_Control: CGKeyCode = 0x3B
    static let kVK_RightCommand: CGKeyCode = 0x36
    static let kVK_RightShift: CGKeyCode = 0x3C
    static let kVK_RightOption: CGKeyCode = 0x3D
    static let kVK_RightControl: CGKeyCode = 0x3E
    static let kVK_Function: CGKeyCode = 0x3F
    static let kVK_F17: CGKeyCode = 0x40
    static let kVK_VolumeUp: CGKeyCode = 0x48
    static let kVK_VolumeDown: CGKeyCode = 0x49
    static let kVK_Mute: CGKeyCode = 0x4A
    static let kVK_F18: CGKeyCode = 0x4F
    static let kVK_F19: CGKeyCode = 0x50
    static let kVK_F20: CGKeyCode = 0x5A
    static let kVK_F5: CGKeyCode = 0x60
    static let kVK_F6: CGKeyCode = 0x61
    static let kVK_F7: CGKeyCode = 0x62
    static let kVK_F3: CGKeyCode = 0x63
    static let kVK_F8: CGKeyCode = 0x64
    static let kVK_F9: CGKeyCode = 0x65
    static let kVK_F11: CGKeyCode = 0x67
    static let kVK_F13: CGKeyCode = 0x69
    static let kVK_F16: CGKeyCode = 0x6A
    static let kVK_F14: CGKeyCode = 0x6B
    static let kVK_F10: CGKeyCode = 0x6D
    static let kVK_F12: CGKeyCode = 0x6F
    static let kVK_F15: CGKeyCode = 0x71
    static let kVK_Help: CGKeyCode = 0x72
    static let kVK_Home: CGKeyCode = 0x73
    static let kVK_PageUp: CGKeyCode = 0x74
    static let kVK_ForwardDelete: CGKeyCode = 0x75
    static let kVK_F4: CGKeyCode = 0x76
    static let kVK_End: CGKeyCode = 0x77
    static let kVK_F2: CGKeyCode = 0x78
    static let kVK_PageDown: CGKeyCode = 0x79
    static let kVK_F1: CGKeyCode = 0x7A
    static let kVK_LeftArrow: CGKeyCode = 0x7B
    static let kVK_RightArrow: CGKeyCode = 0x7C
    static let kVK_DownArrow: CGKeyCode = 0x7D
    static let kVK_UpArrow: CGKeyCode = 0x7E

    // When the globe key is being pressed
    static let kVK_LeftArrow_Globe: CGKeyCode = 0x73
    static let kVK_RightArrow_Globe: CGKeyCode = 0x77
    static let kVK_DownArrow_Globe: CGKeyCode = 0x79
    static let kVK_UpArrow_Globe: CGKeyCode = 0x74

    // ISO keyboards only
    static let kVK_ISO_Section: CGKeyCode = 0x0A

    // JIS keyboards only
    static let kVK_JIS_Yen: CGKeyCode = 0x5D
    static let kVK_JIS_Underscore: CGKeyCode = 0x5E
    static let kVK_JIS_KeypadComma: CGKeyCode = 0x5F
    static let kVK_JIS_Eisu: CGKeyCode = 0x66
    static let kVK_JIS_Kana: CGKeyCode = 0x68

    // Some keycodes seem to alter when a modifier key (ex. the globe key) is being pressed.
    var baseKey: CGKeyCode {
        switch self {
        case .kVK_ANSI_KeypadEnter: CGKeyCode.kVK_Return
        case .kVK_LeftArrow_Globe: CGKeyCode.kVK_LeftArrow
        case .kVK_RightArrow_Globe: CGKeyCode.kVK_RightArrow
        case .kVK_DownArrow_Globe: CGKeyCode.kVK_DownArrow
        case .kVK_UpArrow_Globe: CGKeyCode.kVK_UpArrow
        default: self
        }
    }

    var baseModifier: CGKeyCode {
        switch self {
        case .kVK_RightShift: .kVK_Shift
        case .kVK_RightCommand: .kVK_Command
        case .kVK_RightOption: .kVK_Option
        case .kVK_RightControl: .kVK_Control
        default: self
        }
    }

    var isModifier: Bool {
        return (.kVK_RightCommand ... .kVK_Function).contains(self)
    }

    var isOnRightSide: Bool {
        return [.kVK_RightCommand, .kVK_RightControl, .kVK_RightOption, .kVK_RightShift].contains(self)
    }

    var isPressed: Bool {
        CGEventSource.keyState(.combinedSessionState, key: self)
    }

    // From https://github.com/sindresorhus/KeyboardShortcuts/ but edited a bit
    static let keyToString: [CGKeyCode: String] = [
        .kVK_Return: "↩",
        .kVK_Delete: "⌫",
        .kVK_ForwardDelete: "⌦",
        .kVK_End: "↘",
        .kVK_Escape: "⎋",
        .kVK_Help: "?⃝",
        .kVK_Home: "↖",
        .kVK_Space: "␣",
        .kVK_Tab: "⇥",
        .kVK_PageUp: "⇞",
        .kVK_PageDown: "⇟",
        .kVK_UpArrow: "↑",
        .kVK_RightArrow: "→",
        .kVK_DownArrow: "↓",
        .kVK_LeftArrow: "←",
        .kVK_F1: "F1",
        .kVK_F2: "F2",
        .kVK_F3: "F3",
        .kVK_F4: "F4",
        .kVK_F5: "F5",
        .kVK_F6: "F6",
        .kVK_F7: "F7",
        .kVK_F8: "F8",
        .kVK_F9: "F9",
        .kVK_F10: "F10",
        .kVK_F11: "F11",
        .kVK_F12: "F12",
        .kVK_F13: "F13",
        .kVK_F14: "F14",
        .kVK_F15: "F15",
        .kVK_F16: "F16",
        .kVK_F17: "F17",
        .kVK_F18: "F18",
        .kVK_F19: "F19",
        .kVK_F20: "F20",

        // Representations for numeric keypad keys with   ⃣  Unicode U+20e3 'COMBINING ENCLOSING KEYCAP'
        .kVK_ANSI_Keypad0: "0\u{20e3}",
        .kVK_ANSI_Keypad1: "1\u{20e3}",
        .kVK_ANSI_Keypad2: "2\u{20e3}",
        .kVK_ANSI_Keypad3: "3\u{20e3}",
        .kVK_ANSI_Keypad4: "4\u{20e3}",
        .kVK_ANSI_Keypad5: "5\u{20e3}",
        .kVK_ANSI_Keypad6: "6\u{20e3}",
        .kVK_ANSI_Keypad7: "7\u{20e3}",
        .kVK_ANSI_Keypad8: "8\u{20e3}",
        .kVK_ANSI_Keypad9: "9\u{20e3}",
        // There's "⌧“ 'X In A Rectangle Box' (U+2327), "☒" 'Ballot Box with X' (U+2612), "×" 'Multiplication Sign' (U+00d7), "⨯" 'Vector or Cross Product' (U+2a2f), or a plain small x. All combined symbols appear bigger.
        .kVK_ANSI_KeypadClear: "☒\u{20e3}", // The combined symbol appears bigger than the other combined 'keycaps'
        // TODO: Respect locale decimal separator ("." or ",")
            .kVK_ANSI_KeypadDecimal: ".\u{20e3}",
        .kVK_ANSI_KeypadDivide: "/\u{20e3}",
        // "⏎" 'Return Symbol' (U+23CE) but "↩" 'Leftwards Arrow with Hook' (U+00d7) seems to be more common on macOS.
        .kVK_ANSI_KeypadEnter: "↩\u{20e3}", // The combined symbol appears bigger than the other combined 'keycaps'
        .kVK_ANSI_KeypadEquals: "=\u{20e3}",
        .kVK_ANSI_KeypadMinus: "-\u{20e3}",
        .kVK_ANSI_KeypadMultiply: "*\u{20e3}",
        .kVK_ANSI_KeypadPlus: "+\u{20e3}",
    ]

    // Make sure to use baseModifier before using this!
    static let keyToImage: [CGKeyCode: String] = [
        .kVK_Function: "globe",
        .kVK_Shift: "shift",
        .kVK_Command: "command",
        .kVK_Control: "control",
        .kVK_Option: "option"
    ]

    // Big thanks to https://github.com/sindresorhus/KeyboardShortcuts/
    var humanReadable: String? {
        guard
            let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
            let layoutDataPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else {
            return nil
        }

        let layoutData = unsafeBitCast(
            layoutDataPointer,
            to: CFData.self
        )
        let keyLayout = unsafeBitCast(
            CFDataGetBytePtr(layoutData),
            to: UnsafePointer<CoreServices.UCKeyboardLayout>.self
        )
        var deadKeyState: UInt32 = 0
        let maxLength = 4
        var length = 0
        var characters = [UniChar](repeating: 0, count: maxLength)

        if let character = CGKeyCode.keyToString[self] {
            return character
        } else {
            let error = CoreServices.UCKeyTranslate(
                keyLayout,
                UInt16(self),
                UInt16(CoreServices.kUCKeyActionDisplay),
                0, // No modifiers
                UInt32(LMGetKbdType()),
                OptionBits(CoreServices.kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                maxLength,
                &length,
                &characters
            )

            guard error == noErr else {
                return nil
            }

            return String(utf16CodeUnits: characters, count: length)
        }
    }

    static var systemKeybinds: [Set<CGKeyCode>] {
        var shortcutsUnmanaged: Unmanaged<CFArray>?
        guard
            CopySymbolicHotKeys(&shortcutsUnmanaged) == noErr,
            let shortcuts = shortcutsUnmanaged?.takeRetainedValue() as? [[String: Any]]
        else {
            assertionFailure("Could not get system keyboard shortcuts")
            return []
        }

        return shortcuts.compactMap {
            guard
                ($0[kHISymbolicHotKeyEnabled] as? Bool) == true,
                let carbonKeyCode = $0[kHISymbolicHotKeyCode] as? CGKeyCode,
                let carbonModifiers = $0[kHISymbolicHotKeyModifiers] as? UInt
            else {
                return nil
            }

            let modifiers = NSEvent.ModifierFlags(rawValue: carbonModifiers)
            var result = modifiers.convertToCGKeyCode()
            result.insert(carbonKeyCode)

            return result
        }
    }

    var systemImage: String? {
        if let systemName = CGKeyCode.keyToImage[self.baseModifier] {
            return systemName
        } else {
            return nil
        }
    }

    var triggerkeyLabel: Text {
        let sideText: String

        if self.isOnRightSide {
            sideText = String(localized: "Right", comment: "Prefix for a modifier key on the right side of the keyboard")
        } else {
            sideText = String(localized: "Left", comment: "Prefix for a modifier key on the left side of the keyboard")
        }

        return Text("\(sideText) \(Image(systemName: self.systemImage ?? "exclamationmark.circle.fill"))")
    }
}

extension NSEvent.ModifierFlags {
    func convertToCGKeyCode() -> Set<CGKeyCode> {
        let deviceIndependent = self.intersection(.deviceIndependentFlagsMask)
        var result: Set<CGKeyCode> = []

        if deviceIndependent.contains(.command) {
            result.insert(.kVK_Command)
        }

        if deviceIndependent.contains(.shift) {
            result.insert(.kVK_Shift)
        }

        if deviceIndependent.contains(.option) {
            result.insert(.kVK_Option)
        }

        if deviceIndependent.contains(.control) {
            result.insert(.kVK_Control)
        }

        if deviceIndependent.contains(.function) {
            result.insert(.kVK_Function)
        }

        return result
    }
}
