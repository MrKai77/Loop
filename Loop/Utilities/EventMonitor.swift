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

class NSEventMonitor: EventMonitor, Identifiable, Equatable {
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    private let scope: NSEventMonitor.Scope
    private let eventTypeMask: NSEvent.EventTypeMask
    private let eventHandler: (NSEvent) -> (NSEvent?)

    var isEnabled: Bool = false

    enum Scope {
        case local
        case global
        case all
    }

    deinit {
        if isEnabled {
            stop()
        }

        // Clear references
        localEventMonitor = nil
        globalEventMonitor = nil
    }

    init(scope: Scope, eventMask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> (NSEvent?)) {
        self.eventTypeMask = eventMask
        self.eventHandler = handler
        self.scope = scope
    }

    func start() {
        if scope == .local || scope == .all {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(
                matching: eventTypeMask,
                handler: { [weak self] event in
                    self?.eventHandler(event)
                }
            )
        }

        if scope == .global || scope == .all {
            globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: eventTypeMask,
                handler: { [weak self] event in
                    _ = self?.eventHandler(event)
                }
            )
        }

        isEnabled = true
    }

    func stop() {
        guard isEnabled else { return }

        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }

        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
        isEnabled = false
    }

    let id = UUID()
    static func == (lhs: NSEventMonitor, rhs: NSEventMonitor) -> Bool {
        lhs.id == rhs.id
    }
}

class CGEventMonitor: EventMonitor, Identifiable, Equatable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var eventCallback: (CGEvent) -> Unmanaged<CGEvent>?
    var isEnabled: Bool = false

    init(eventMask: NSEvent.EventTypeMask, callback: @escaping (CGEvent) -> Unmanaged<CGEvent>?) {
        self.eventCallback = callback

        self.eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask.rawValue,
            callback: { _, _, event, refcon in
                let observer = Unmanaged<CGEventMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                return observer.handleEvent(event: event)
            },
            userInfo: Unmanaged.passRetained(self).toOpaque()
        )

        if let eventTap {
            self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            if let runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
        } else {
            print("ERROR: Failed to create event tap (event mask: \(eventMask)")
        }
    }

    deinit {
        if isEnabled {
            stop()
        }

        // Clean up run loop source and event tap
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if eventTap != nil {
            self.eventTap = nil
        }
    }

    private func handleEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
        eventCallback(event)
    }

    func start() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        isEnabled = true
    }

    func stop() {
        guard isEnabled else { return }

        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: false)
        isEnabled = false
    }

    var id = UUID()
    static func == (lhs: CGEventMonitor, rhs: CGEventMonitor) -> Bool {
        lhs.id == rhs.id
    }
}
