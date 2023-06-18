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
    
    func start() {
        if eventTap == nil {
            let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            let eventCallback: CGEventTapCallBack = { _, _, event, _ in
                if RadialMenuKeybindMonitor.shared.isEnabled,
                    let keyEvent = NSEvent(cgEvent: event) {
                    
                 
                    if keyEvent.keyCode == KeyCode.escape {
                        NotificationCenter.default.post(name: Notification.Name.closeLoop, object: nil, userInfo: ["wasForceClosed": true])
                        return nil
                    }
                    
                    if keyEvent.keyCode == KeyCode.w || keyEvent.keyCode == KeyCode.upArrow {
                        NotificationCenter.default.post(name: Notification.Name.currentDirectionChanged, object: nil, userInfo: ["Direction": WindowDirection.topHalf])
                        return nil
                    }
                    
                    if keyEvent.keyCode == KeyCode.a || keyEvent.keyCode == KeyCode.leftArrow {
                        NotificationCenter.default.post(name: Notification.Name.currentDirectionChanged, object: nil, userInfo: ["Direction": WindowDirection.leftHalf])
                        return nil
                    }
                    
                    if keyEvent.keyCode == KeyCode.s || keyEvent.keyCode == KeyCode.downArrow {
                        NotificationCenter.default.post(name: Notification.Name.currentDirectionChanged, object: nil, userInfo: ["Direction": WindowDirection.bottomHalf])
                        return nil
                    }
                    
                    if keyEvent.keyCode == KeyCode.d || keyEvent.keyCode == KeyCode.rightArrow {
                        NotificationCenter.default.post(name: Notification.Name.currentDirectionChanged, object: nil, userInfo: ["Direction": WindowDirection.rightHalf])
                        return nil
                    }
                    
                    if keyEvent.keyCode == KeyCode.space {  // Space Key
                        NotificationCenter.default.post(name: Notification.Name.currentDirectionChanged, object: nil, userInfo: ["Direction": WindowDirection.maximize])
                        return nil
                    }
                }

                // Forward the event to other apps
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
