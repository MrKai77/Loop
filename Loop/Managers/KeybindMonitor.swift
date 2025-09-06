//
//  KeybindMonitor.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-18.
//

import Cocoa
import Defaults

class KeybindMonitor {
    static let shared = KeybindMonitor()

    private var eventMonitor: CGEventMonitor?
    private var flagsEventMonitor: CGEventMonitor?
    private var pressedKeys = Set<CGKeyCode>()
    private var lastKey: CGKeyCode?
    private var lastKeyReleaseTime: Date = .now

    // Currently, special events only contain the globe key, as it can also be used as a emoji key.
    private let specialEvents: [CGKeyCode] = [179]
    var canPassthroughSpecialEvents = true // If mouse has been moved

    func resetPressedKeys() {
        KeybindMonitor.shared.pressedKeys = []
        lastKey = nil
    }

    func start() {
        guard eventMonitor == nil,
              AccessibilityManager.getStatus() else {
            return
        }

        eventMonitor = CGEventMonitor(eventMask: [.keyDown, .keyUp]) { cgEvent in
            guard
                cgEvent.type == .keyDown || cgEvent.type == .keyUp,
                let event = NSEvent(cgEvent: cgEvent)
            else {
                return Unmanaged.passUnretained(cgEvent)
            }

            if event.type == .keyUp {
                KeybindMonitor.shared.pressedKeys.remove(event.keyCode.baseKey)
            } else if event.type == .keyDown {
                KeybindMonitor.shared.pressedKeys.insert(event.keyCode.baseKey)
                KeybindMonitor.shared.lastKey = event.keyCode.baseKey
            }

            // Special events such as the emoji key
            if self.specialEvents.contains(event.keyCode.baseKey) {
                if self.canPassthroughSpecialEvents {
                    return Unmanaged.passUnretained(cgEvent)
                }
                return nil
            }

            // If this is a valid event, don't passthrough
            if self.performKeybind(event: event) {
                return nil
            }

            // If this wasn't, check if it was a system keybind (ex. screenshot), and
            // in that case, passthrough and force-close Loop
            if CGKeyCode.systemKeybinds.contains(self.pressedKeys) {
                LoopManager.shared.forceCloseLoop()
                print("Detected system keybind, closing!")
                return Unmanaged.passUnretained(cgEvent)
            }

            return Unmanaged.passUnretained(cgEvent)
        }

        flagsEventMonitor = CGEventMonitor(eventMask: .flagsChanged) { cgEvent in
            if cgEvent.type == .flagsChanged,
               let event = NSEvent(cgEvent: cgEvent),
               !Defaults[.triggerKey].contains(where: { $0.baseModifier == event.keyCode.baseModifier }) {
                self.checkForModifier(event, .kVK_Shift, .shift)
                self.checkForModifier(event, .kVK_Command, .command)
                self.checkForModifier(event, .kVK_Option, .option)
                self.checkForModifier(event, .kVK_Function, .function)

                self.performKeybind(event: event)
            }
            return Unmanaged.passUnretained(cgEvent)
        }

        eventMonitor!.start()
        flagsEventMonitor!.start()
    }

    func stop() {
        resetPressedKeys()
        canPassthroughSpecialEvents = true

        eventMonitor?.stop()
        eventMonitor = nil

        flagsEventMonitor?.stop()
        flagsEventMonitor = nil
    }

    @discardableResult
    private func performKeybind(event: NSEvent) -> Bool {
        if event.type == .keyUp {
            // If the current key up event is within 100 ms of the last key up event, return.
            // This is used when the user is pressing 2+ keys so that it doesn't switch back
            // to the one key direction when they're letting go of the keys.
            if abs(lastKeyReleaseTime.timeIntervalSinceNow) < 0.1 {
                print("performKeybind: valid event detected; not passing through due to rapid key release")
                return true
            }
            lastKeyReleaseTime = Date.now
            return true
        }

        LoopManager.shared.isShiftKeyPressed = event.modifierFlags.contains(.shift)

        if pressedKeys.contains(.kVK_Escape) {
            LoopManager.shared.forceCloseLoop()
            print("performKeybind: valid event detected; not passing through due to force-closing of Loop")
            return true
        }

        if let newAction = WindowAction.getAction(for: pressedKeys) {
            let isRepeatEvent = (event.type == .keyDown || event.type == .keyUp) && event.isARepeat

            if !isRepeatEvent || newAction.willManipulateExistingWindowFrame {
                LoopManager.shared.changeAction(newAction)
                print("performKeybind: valid event detected; new action: \(newAction.direction)")
            }

            return true
        }

        // If this wasn't a valid keybind, return false, which will then forward the key event to the frontmost app
        return false
    }

    private func checkForModifier(_ event: NSEvent, _ key: CGKeyCode, _ modifierFlag: NSEvent.ModifierFlags) {
        if event.keyCode.baseKey == key {
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(modifierFlag) {
                KeybindMonitor.shared.pressedKeys.insert(key)
            } else {
                KeybindMonitor.shared.pressedKeys.remove(key)
            }
        }
    }
}
