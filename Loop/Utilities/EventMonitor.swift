//
//  EventMonitor.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-07.
//

import Cocoa

protocol EventMonitor {
    var isEnabled: Bool { get }
    func start()
    func stop()
}

class NSEventMonitor: EventMonitor {
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    private var scope: NSEventMonitor.Scope
    private var eventTypeMask: NSEvent.EventTypeMask
    private var eventHandler: (NSEvent) -> Void
    var isEnabled: Bool = false

    enum Scope {
        case local
        case global
        case all
    }

    init(scope: Scope, eventMask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) {
        self.eventTypeMask = eventMask
        self.eventHandler = handler
        self.scope = scope
    }

    public func start() {
        guard self.isEnabled == false else { return }

        if self.scope == .local || self.scope == .all {
            self.localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: eventTypeMask) { event in
                self.eventHandler(event)
                return event
            }
        }
        if self.scope == .global || self.scope == .all {
            self.globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventTypeMask, handler: eventHandler)
        }

        self.isEnabled = true
    }

    public func stop() {
        guard self.isEnabled == true else { return }

        if self.localEventMonitor != nil {
            NSEvent.removeMonitor(self.localEventMonitor!)
            self.localEventMonitor = nil
        }
        if self.globalEventMonitor != nil {
            NSEvent.removeMonitor(self.globalEventMonitor!)
            self.globalEventMonitor = nil
        }

        self.isEnabled = false
    }
}

class CGEventMonitor: EventMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var eventCallback: (CGEvent) -> Unmanaged<CGEvent>?
    var isEnabled: Bool = false

    init(eventMask: NSEvent.EventTypeMask, callback: @escaping (CGEvent) -> Unmanaged<CGEvent>?) {
        self.eventCallback = callback

        self.eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask.rawValue,
            callback: { _, _, event, refcon in
                let observer = Unmanaged<CGEventMonitor>.fromOpaque(refcon!).takeUnretainedValue()
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

    private func handleEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
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
