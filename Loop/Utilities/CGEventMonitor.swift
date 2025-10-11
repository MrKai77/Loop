//
//  CGEventMonitor.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-10.
//

import Cocoa
import OSLog

// Base class to share common functionality. DO NOT USE DIRECTLY!
class BaseCGEventMonitor: Identifiable, Equatable {
    let id = UUID()
    private let logger = Logger(subsystem: Bundle.main.bundleID, category: "BaseCGEventMonitor")

    private var eventTap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isEnabled: Bool = false

    func setupRunLoopSource(eventTap: CFMachPort, runLoop: CFRunLoop) {
        if let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) {
            self.eventTap = eventTap
            self.runLoop = runLoop
            self.runLoopSource = runLoopSource
            CFRunLoopAddSource(runLoop, runLoopSource, .commonModes)
        }
    }

    func start() {
        guard let eventTap else { return }

        // swiftformat:disable:next redundantSelf
        logger.info("Starting BaseCGEventMonitor with ID \(self.id)")

        CGEvent.tapEnable(tap: eventTap, enable: true)
        isEnabled = true
    }

    func stop() {
        guard let eventTap else { return }
        
        // swiftformat:disable:next redundantSelf
        logger.info("Stopping BaseCGEventMonitor with ID \(self.id)")

        CGEvent.tapEnable(tap: eventTap, enable: false)
        isEnabled = false
    }

    deinit {
        if isEnabled {
            stop()
        }

        // Clean up run loop source and event tap
        if let runLoop, let runLoopSource {
            CFRunLoopRemoveSource(runLoop, runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    static func == (lhs: BaseCGEventMonitor, rhs: BaseCGEventMonitor) -> Bool {
        lhs.id == rhs.id
    }
}

// Original active monitor that can process and alter events
class ActiveCGEventMonitor: BaseCGEventMonitor {
    private let eventCallback: (CGEvent) -> Unmanaged<CGEvent>?

    init(
        tapLocation: CGEventTapLocation,
        placement: CGEventTapPlacement,
        eventMask: CGEventMask,
        callback: @escaping (CGEvent) -> Unmanaged<CGEvent>?
    ) {
        self.eventCallback = callback
        super.init()

        let callback: CGEventTapCallBack = { _, _, event, refcon in
            // Try and obtain a reference to self, but if we fail, just return the unprocessed event.
            guard let refcon else {
                return Unmanaged.passUnretained(event)
            }
            let observer = Unmanaged<ActiveCGEventMonitor>.fromOpaque(refcon).takeUnretainedValue()

            // If disabled, simply pass the event through, but attempt to restart the event tap.
            if event.type == .tapDisabledByTimeout || event.type == .tapDisabledByUserInput {
                observer.start()
                return Unmanaged.passUnretained(event)
            }

            return observer.handleEvent(event: event)
        }
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        if let eventTap = CGEvent.tapCreate(
            tap: tapLocation,
            place: placement,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: userInfo
        ) {
            setupRunLoopSource(eventTap: eventTap, runLoop: CFRunLoopGetCurrent())
        } else {
            Unmanaged<Self>.fromOpaque(userInfo).release()
        }
    }

    private func handleEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
        eventCallback(event)
    }
}

// Passive monitor that only listens to events.
// Callback will be called on a separate thread to keep the CFMachPort's callback fast.
class PassiveCGEventMonitor: BaseCGEventMonitor {
    private let eventCallback: (CGEvent) -> ()

    init(
        tapLocation: CGEventTapLocation,
        placement: CGEventTapPlacement,
        eventMask: CGEventMask,
        callback: @escaping (CGEvent) -> ()
    ) {
        self.eventCallback = callback
        super.init()

        let callback: CGEventTapCallBack = { _, _, event, refcon in
            // Try and obtain a reference to self
            guard let refcon else {
                return Unmanaged.passUnretained(event)
            }
            let observer = Unmanaged<PassiveCGEventMonitor>.fromOpaque(refcon).takeUnretainedValue()

            // If disabled, attempt to restart the event tap
            if event.type == .tapDisabledByTimeout || event.type == .tapDisabledByUserInput {
                observer.start()
                return Unmanaged.passUnretained(event)
            }

            // Call the callback but always pass the unmodified event through
            observer.handleEvent(event: event)
            return Unmanaged.passUnretained(event)
        }
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        if let eventTap = CGEvent.tapCreate(
            tap: tapLocation,
            place: placement,
            options: .listenOnly, // Use listenOnly mode
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: userInfo
        ) {
            setupRunLoopSource(eventTap: eventTap, runLoop: CFRunLoopGetCurrent())
        } else {
            Unmanaged<Self>.fromOpaque(userInfo).release()
        }
    }

    private func handleEvent(event: CGEvent) {
        Task {
            eventCallback(event)
        }
    }
}
