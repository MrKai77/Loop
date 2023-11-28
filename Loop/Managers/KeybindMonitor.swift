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
    private var lastKeyReleaseTime: Date = Date.now

    func resetPressedKeys() {
        KeybindMonitor.shared.pressedKeys = []
    }

    private func performKeybind(event: NSEvent) {
        // If the current key up event is within 100 ms of the last key up event, return.
        // This is used when the user is pressing 2+ keys so that it doesn't switch back
        // to the one key direction when they're letting go of the keys.
        if event.type == .keyUp ||
            (event.type == .flagsChanged &&
             !event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift)) {
            if (abs(lastKeyReleaseTime.timeIntervalSinceNow)) > 0.1 {
                return
            }
            lastKeyReleaseTime = Date.now
        }

        if pressedKeys.contains(.kVK_Escape) {
            Notification.Name.forceCloseLoop.post()
            KeybindMonitor.shared.resetPressedKeys()
            return
        }

        if let newDirection = WindowDirection.getDirection(for: pressedKeys) {
            Notification.Name.directionChanged.post(userInfo: ["direction": newDirection])
        }
    }

    func start() {
        guard self.eventMonitor == nil,
              PermissionsManager.Accessibility.getStatus() else {
            return
        }

        self.eventMonitor = CGEventMonitor(eventMask: [.keyDown, .keyUp]) { cgEvent in
             if cgEvent.type == .keyDown || cgEvent.type == .keyUp,
               let event = NSEvent(cgEvent: cgEvent),
               !event.isARepeat {

                if event.type == .keyUp {
                    KeybindMonitor.shared.pressedKeys.remove(event.keyCode.baseKey)
                } else if event.type == .keyDown {
                    KeybindMonitor.shared.pressedKeys.insert(event.keyCode.baseKey)
                }

                self.performKeybind(event: event)
            }

            return nil
        }

        self.flagsEventMonitor = CGEventMonitor(eventMask: .flagsChanged) { cgEvent in
            if cgEvent.type == .flagsChanged,
               let event = NSEvent(cgEvent: cgEvent),
               !Defaults[.triggerKey].contains(where: { $0.baseModifier == event.keyCode.baseModifier }) {
                
                self.checkForModifier(event, .kVK_Shift, .shift)
                self.checkForModifier(event, .kVK_Command, .command)
                self.checkForModifier(event, .kVK_Option, .option)
                self.checkForModifier(event, .kVK_Function, .function)
                self.checkForModifier(event, .kVK_Control, .control)

                print(KeybindMonitor.shared.pressedKeys)

                self.performKeybind(event: event)
            }
            return Unmanaged.passUnretained(cgEvent)
        }

        self.eventMonitor!.start()
        self.flagsEventMonitor!.start()
    }

    func stop() {
        guard self.eventMonitor != nil &&
              self.flagsEventMonitor != nil else {
            return
        }
        self.eventMonitor?.stop()
        self.eventMonitor = nil

        self.flagsEventMonitor?.stop()
        self.flagsEventMonitor = nil
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
