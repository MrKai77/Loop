//
//  EventMonitor.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-07.
//

import Cocoa

class EventMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var eventCallback: (CGEvent) -> Unmanaged<CGEvent>

    var isEnabled: Bool = false

    init(eventMask: NSEvent.EventTypeMask, eventCallback: @escaping (CGEvent) -> Unmanaged<CGEvent>) {
        self.eventCallback = eventCallback

        self.eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask.rawValue,
            callback: { _, _, event, refcon in
                let observer = Unmanaged<EventMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                return observer.handleEvent(event: event)
            },
            userInfo: Unmanaged.passRetained(self).toOpaque()
        )

        if let eventTap = self.eventTap {
            self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            if let runLoopSource = self.runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
        } else {
            fatalError("Failed to create event tap")
        }
    }

    private func handleEvent(event: CGEvent) -> Unmanaged<CGEvent> {
        return self.eventCallback(event)
    }

    func start() {
        if let eventTap = self.eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
        self.isEnabled = true
    }

    func stop() {
        if let eventTap = self.eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        self.isEnabled = false
    }
}
