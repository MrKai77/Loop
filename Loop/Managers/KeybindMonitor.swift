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
    private var shiftKeyEventMonitor: CGEventMonitor?
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

        self.shiftKeyEventMonitor = CGEventMonitor(eventMask: .flagsChanged) { cgEvent in
            if cgEvent.type == .flagsChanged,
               let event = NSEvent(cgEvent: cgEvent),
               !Defaults[.triggerKey].contains(event.keyCode) {

                if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift) {
                    KeybindMonitor.shared.pressedKeys.insert(.kVK_Shift)
                } else {
                    KeybindMonitor.shared.pressedKeys.remove(.kVK_Shift)
                }
                self.performKeybind(event: event)
            }
            return Unmanaged.passUnretained(cgEvent)
        }

        self.eventMonitor!.start()
        self.shiftKeyEventMonitor!.start()
    }

    func stop() {
        guard self.eventMonitor != nil &&
              self.shiftKeyEventMonitor != nil else {
            return
        }
        self.eventMonitor?.stop()
        self.eventMonitor = nil

        self.shiftKeyEventMonitor?.stop()
        self.shiftKeyEventMonitor = nil
    }
}
