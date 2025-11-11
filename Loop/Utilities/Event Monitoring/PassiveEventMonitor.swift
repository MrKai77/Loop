//
//  PassiveEventMonitor.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-12.
//

import CoreGraphics

/// Passive monitor that only listens to events.
/// Callback will be called on a separate thread to keep the CFMachPort's callback fast.
final class PassiveEventMonitor: BaseEventTapMonitor {
    private let eventCallback: (CGEvent) -> ()

    ///  Initializes a `PassiveEventMonitor`.
    /// - Parameters:
    ///   - tapLocation: the location at which this event tap will be placed.
    ///   - placement:  whether to add this monitor as a head or tail relative to other event monitors within this tap.
    ///   - events:  the events to capture within this event monitor.
    ///   - callback:  a callback to process the received event.
    init(
        tapLocation: CGEventTapLocation = .cgSessionEventTap,
        placement: CGEventTapPlacement = .tailAppendEventTap,
        events: [CGEventType],
        callback: @escaping (CGEvent) -> ()
    ) {
        self.eventCallback = callback
        super.init()

        let eventsOfInterest = events.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, _, event, refcon in
            // Try and obtain a reference to self
            guard let refcon else {
                return Unmanaged.passUnretained(event)
            }
            let observer = Unmanaged<PassiveEventMonitor>.fromOpaque(refcon).takeUnretainedValue()

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
            options: .listenOnly,
            eventsOfInterest: eventsOfInterest,
            callback: callback,
            userInfo: userInfo
        ) {
            setupRunLoopSource(eventTap: eventTap, runLoop: CFRunLoopGetCurrent())
        } else {
            super.logger.info("Failed to create event tap")
        }
    }

    private func handleEvent(event: CGEvent) {
        Task {
            eventCallback(event)
        }
    }
}
