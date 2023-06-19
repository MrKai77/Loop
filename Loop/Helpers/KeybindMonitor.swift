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
    private var pressedKeys = Set<UInt16>()
    private var lastKeyReleaseTime: Date = Date.now
    
    private func performKeybind(event: NSEvent) -> Bool {
        
        var isValidKeybind = false
        
        // If the current key up event is within 100 ms of the last key up event, return.
        // This is used when the user is pressing 2+ keys so that it doesn't switch back
        // to the one key direction when they're letting go of the keys.
        if event.type == .keyUp {
            if (abs(lastKeyReleaseTime.timeIntervalSinceNow)) > 0.1 {
                lastKeyReleaseTime = Date.now
            }
            return false
        }
        
        if pressedKeys == [KeyCode.escape] {
            NotificationCenter.default.post(
                name: Notification.Name.closeLoop,
                object: nil,
                userInfo: ["wasForceClosed": true]
            )
            isValidKeybind = true
        }
        
        for direction in WindowDirection.allCases {
            for keybind in direction.keybindings {
                if keybind == pressedKeys {
                    NotificationCenter.default.post(
                        name: Notification.Name.currentDirectionChanged,
                        object: nil,
                        userInfo: ["Direction": direction]
                    )
                }
                isValidKeybind = true
            }
        }
        
        return isValidKeybind
    }
    
    func start() {
        if eventTap == nil {
            let eventMask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue))
            
            let eventCallback: CGEventTapCallBack = { _, _, event, _ in
                if KeybindMonitor.shared.isEnabled,
                    let keyEvent = NSEvent(cgEvent: event) {
                    
                    if !keyEvent.isARepeat {
                        if keyEvent.type == .keyUp {
                            KeybindMonitor.shared.pressedKeys.remove(keyEvent.keyCode)
                        } else if keyEvent.type == .keyDown {
                            KeybindMonitor.shared.pressedKeys.insert(keyEvent.keyCode)
                        }
                    }
                    
                    if KeybindMonitor.shared.performKeybind(event: keyEvent) {
                        return nil
                    }
                }
                
                 return Unmanaged.passRetained(event)
            }

            let newEventTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                                place: .headInsertEventTap,
                                                options: .defaultTap,
                                                eventsOfInterest: eventMask,
                                                callback: eventCallback,
                                                userInfo: nil)

            self.eventTap = newEventTap

            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newEventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: newEventTap!, enable: true)
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
