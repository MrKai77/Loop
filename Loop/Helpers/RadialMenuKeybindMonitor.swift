//
//  KeyInterceptor.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-18.
//

import Cocoa

class RadialMenuKeybindMonitor {
    
    static let shared = RadialMenuKeybindMonitor()
    
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
        
        if pressedKeys == [KeyCode.w] || pressedKeys == [KeyCode.upArrow] {
            NotificationCenter.default.post(
                name: Notification.Name.currentDirectionChanged,
                object: nil,
                userInfo: ["Direction": WindowDirection.topHalf]
            )
            isValidKeybind = true
        }
        
        if pressedKeys == [KeyCode.w, KeyCode.a] || pressedKeys == [KeyCode.upArrow, KeyCode.leftArrow] {
            NotificationCenter.default.post(
                name: Notification.Name.currentDirectionChanged,
                object: nil,
                userInfo: ["Direction": WindowDirection.topLeftQuarter]
            )
            isValidKeybind = true
        }
        
        if pressedKeys == [KeyCode.a] || pressedKeys == [KeyCode.leftArrow] {
            NotificationCenter.default.post(
                name: Notification.Name.currentDirectionChanged,
                object: nil,
                userInfo: ["Direction": WindowDirection.leftHalf]
            )
            isValidKeybind = true
        }
        
        if pressedKeys == [KeyCode.a, KeyCode.s] || pressedKeys == [KeyCode.leftArrow, KeyCode.downArrow] {
            NotificationCenter.default.post(
                name: Notification.Name.currentDirectionChanged,
                object: nil,
                userInfo: ["Direction": WindowDirection.bottomLeftQuarter]
            )
            isValidKeybind = true
        }
        
        if pressedKeys == [KeyCode.s] || pressedKeys == [KeyCode.downArrow] {
            NotificationCenter.default.post(
                name: Notification.Name.currentDirectionChanged,
                object: nil,
                userInfo: ["Direction": WindowDirection.bottomHalf]
            )
            isValidKeybind = true
        }
        
        if pressedKeys == [KeyCode.s, KeyCode.d] || pressedKeys == [KeyCode.downArrow, KeyCode.rightArrow] {
            NotificationCenter.default.post(
                name: Notification.Name.currentDirectionChanged,
                object: nil,
                userInfo: ["Direction": WindowDirection.bottomRightQuarter]
            )
            isValidKeybind = true
        }
        
        if pressedKeys == [KeyCode.d] || pressedKeys == [KeyCode.rightArrow] {
            NotificationCenter.default.post(
                name: Notification.Name.currentDirectionChanged,
                object: nil,
                userInfo: ["Direction": WindowDirection.rightHalf]
            )
            isValidKeybind = true
        }
        
        if pressedKeys == [KeyCode.d, KeyCode.w] || pressedKeys == [KeyCode.rightArrow, KeyCode.upArrow] {
            NotificationCenter.default.post(
                name: Notification.Name.currentDirectionChanged,
                object: nil,
                userInfo: ["Direction": WindowDirection.topRightQuarter]
            )
            isValidKeybind = true
        }
        
        if pressedKeys == [KeyCode.space] {
            NotificationCenter.default.post(
                name: Notification.Name.currentDirectionChanged,
                object: nil,
                userInfo: ["Direction": WindowDirection.maximize]
            )
            isValidKeybind = true
        }
        
        return isValidKeybind
    }
    
    func start() {
        if eventTap == nil {
            let eventMask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue))
            
            let eventCallback: CGEventTapCallBack = { _, _, event, _ in
                if RadialMenuKeybindMonitor.shared.isEnabled,
                    let keyEvent = NSEvent(cgEvent: event) {
                    
                    if !keyEvent.isARepeat {
                        if keyEvent.type == .keyUp {
                            RadialMenuKeybindMonitor.shared.pressedKeys.remove(keyEvent.keyCode)
                        } else if keyEvent.type == .keyDown {
                            RadialMenuKeybindMonitor.shared.pressedKeys.insert(keyEvent.keyCode)
                        }
                    }
                    
                    if RadialMenuKeybindMonitor.shared.performKeybind(event: keyEvent) {
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