//
//  Keycorder.swift
//  Loop
//
//  Created by Kai Azim on 2023-11-10.
//

import SwiftUI
import Carbon.HIToolbox

struct Keycorder: View {
    @Binding private var validCurrentKeybind: Set<CGKeyCode>

    @State private var eventMonitor: NSEventMonitor?
    @State private var shouldShake: Bool = false
    @State private var isHovering: Bool = false

    @State private var selectionKeybind: Set<CGKeyCode>
    @State private var isActive: Bool = false

    init(key: Binding<Set<CGKeyCode>>) {
        self._validCurrentKeybind = key
        self.selectionKeybind = _validCurrentKeybind.wrappedValue
    }

    let activeAnimation = Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
    let noAnimation = Animation.linear(duration: 0)

    var body: some View {
        Button(action: {
            self.startObservingKeys()
        }, label: {
            HStack(spacing: 5) {
                Text((self.selectionKeybind.isEmpty ? "Press a key..." : self.keybindToCharacter(self.selectionKeybind)) ?? "ERROR")
                    .fontDesign(.monospaced)
            }
            .padding(5)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .foregroundStyle(.background.opacity(self.isActive ? 0.1 : 0.8))
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.tertiary.opacity(self.isHovering ? 1 : 0.5), lineWidth: 1)
                }
            }
        })
        .onHover { hovering in
            self.isHovering = hovering
        }
        .buttonStyle(.plain)
    }

    func startObservingKeys() {
        self.selectionKeybind = []
        self.isActive = true
        self.eventMonitor = NSEventMonitor(scope: .local, eventMask: [.keyDown, .keyUp]) { event in
            if event.type == .keyUp {
                if event.keyCode == CGKeyCode.kVK_Escape {
                    self.selectionKeybind = self.validCurrentKeybind
                } else {
                    self.validCurrentKeybind = self.selectionKeybind
                }

                self.finishedObservingKeys()
                return
            }

            if event.type == .keyDown {
                self.selectionKeybind.insert(event.keyCode)
            }
        }

        self.eventMonitor!.start()
    }

    func finishedObservingKeys() {
        self.isActive = false
        self.eventMonitor?.stop()
        self.eventMonitor = nil
    }

    // Big thanks to https://github.com/sindresorhus/KeyboardShortcuts/
    func keybindToCharacter(_ keybind: Set<CGKeyCode>) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
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

        var resultString = ""

        for keyCode in keybind {
            var keyString = ""

            if let character = CGKeyCode.keyToCharacterMapping[keyCode] {
                keyString = character
            } else {
                let error = CoreServices.UCKeyTranslate(
                    keyLayout,
                    UInt16(keyCode),
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

                keyString = String(utf16CodeUnits: characters, count: length)
            }

            if resultString.isEmpty {
                resultString += keyString
            } else {
                if keyCode.baseModifier == .kVK_Shift {
                    resultString = keyString + " " + resultString
                } else {
                    resultString += " " + keyString
                }
            }
        }

        return resultString
    }
}
