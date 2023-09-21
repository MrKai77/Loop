//
//  KeybindMonitor.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-18.
//

import Cocoa

class KeybindMonitor {
    static let shared = KeybindMonitor()

    private var eventTap: CFMachPort?
    private var isEnabled = false
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
        if eventTap == nil {
            let eventMask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue))

            let eventCallback: CGEventTapCallBack = { _, _, event, _ in
                if KeybindMonitor.shared.isEnabled,
                    let keyEvent = NSEvent(cgEvent: event) {

                    if keyEvent.isARepeat {
                        return nil
                    }

                    if keyEvent.type == .keyUp {
                        KeybindMonitor.shared.pressedKeys.remove(keyEvent.keyCode.baseKey)
                    } else if keyEvent.type == .keyDown {
                        KeybindMonitor.shared.pressedKeys.insert(keyEvent.keyCode.baseKey)
                    }

                    KeybindMonitor.shared.performKeybind(event: keyEvent)
                }

                // If we wanted to forward the key event to the frontmost app, we'd use:
                // return Unmanaged.passRetained(event)
                return nil
            }

            let newEventTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                                place: .headInsertEventTap,
                                                options: .defaultTap,
                                                eventsOfInterest: eventMask,
                                                callback: eventCallback,
                                                userInfo: nil)

            self.eventTap = newEventTap

            if PermissionsManager.Accessibility.getStatus() {
                let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newEventTap, 0)
                CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
                CGEvent.tapEnable(tap: newEventTap!, enable: true)
            }
        }
        isEnabled = true
    }

    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        isEnabled = false
    }
}
