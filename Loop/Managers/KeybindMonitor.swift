//
//  KeybindMonitor.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-18.
//

import Cocoa

class KeybindMonitor {
    static let shared = KeybindMonitor()

    private var eventMonitor: CGEventMonitor?
    private var pressedKeys = Set<CGKeyCode>()
    private var lastKeyReleaseTime: Date = Date.now

    func resetPressedKeys() {
        KeybindMonitor.shared.pressedKeys = []
    }

    private func performKeybind(event: NSEvent) {
        // If the current key up event is within 100 ms of the last key up event, return.
        // This is used when the user is pressing 2+ keys so that it doesn't switch back
        // to the one key direction when they're letting go of the keys.
        if event.type == .keyUp {
            if (abs(lastKeyReleaseTime.timeIntervalSinceNow)) > 0.1 {
                lastKeyReleaseTime = Date.now
            }
            return
        }

        if pressedKeys == [.kVK_Escape] {
            Notification.Name.forceCloseLoop.post()
            KeybindMonitor.shared.resetPressedKeys()
        } else {
            // Since this is one for loop inside another, we can break from inside by breaking from the outerloop
            outerLoop: for direction in WindowDirection.allCases {
                for keybind in direction.keybind where keybind == pressedKeys {
                    Notification.Name.directionChanged.post(userInfo: ["direction": direction])
                    break outerLoop
                }
            }
        }
    }

    func start() {
        guard self.eventMonitor == nil,
              PermissionsManager.Accessibility.getStatus() else {
            return
        }

        self.eventMonitor = CGEventMonitor(eventMask: [.keyDown, .keyUp]) { cgEvent in

            // Even though we already told it its eventMask, not doing the below line throws me a bunch of errors :/
            if (cgEvent.type == .keyDown || cgEvent.type == .keyUp),
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
        self.eventMonitor!.start()
    }

    func stop() {
        guard self.eventMonitor != nil else { return }
        self.eventMonitor!.stop()
        self.eventMonitor = nil
    }
}
