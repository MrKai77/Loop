//
//  ActiveEventMonitor.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-12.
//

import CoreGraphics

/// Active event monitor that can process and alter events when needed.
final class ActiveEventMonitor: BaseEventTapMonitor {
    private let eventCallback: (CGEvent) -> Unmanaged<CGEvent>?

    enum EventHandling {
        case forward
        case ignore
    }

    /// Initializes an `ActiveEventMonitor`, with a simplified callback.
    /// - Parameters:
    ///   - tapLocation: the location at which this event tap will be placed.
    ///   - placement: whether to add this monitor as a head or tail relative to other event monitors within this tap.
    ///   - events: the events to capture within this event monitor.
    ///   - callback: a callback to process received events. Return `forward` to pass the event along, `ignore` to block the event from reaching downstream receivers.
    convenience init(
        tapLocation: CGEventTapLocation = .cgSessionEventTap,
        placement: CGEventTapPlacement = .tailAppendEventTap,
        events: [CGEventType],
        callback: @escaping (CGEvent) -> EventHandling
    ) {
        self.init(
            tapLocation: tapLocation,
            placement: placement,
            events: events,
            callback: { callback($0) == .forward ? Unmanaged.passUnretained($0) : nil }
        )
    }

    /// Initializes an `ActiveEventMonitor`.
    /// - Parameters:
    ///   - tapLocation: the location at which this event tap will be placed.
    ///   - placement: whether to add this monitor as a head or tail relative to other event monitors within this tap.
    ///   - events: the events to capture within this event monitor.
    ///   - callback: a callback to process and potentially alter received events.
    init(
        tapLocation: CGEventTapLocation = .cgSessionEventTap,
        placement: CGEventTapPlacement = .tailAppendEventTap,
        events: [CGEventType],
        callback: @escaping (CGEvent) -> Unmanaged<CGEvent>?
    ) {
        self.eventCallback = callback
        super.init()

        let eventsOfInterest = events.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, _, event, refcon in
            // Try and obtain a reference to self, but if we fail, just return the unprocessed event.
            guard let refcon else {
                return Unmanaged.passUnretained(event)
            }
            let observer = Unmanaged<ActiveEventMonitor>.fromOpaque(refcon).takeUnretainedValue()

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
            eventsOfInterest: eventsOfInterest,
            callback: callback,
            userInfo: userInfo
        ) {
            setupRunLoopSource(eventTap: eventTap, runLoop: CFRunLoopGetCurrent())
        } else {
            super.logger.info("Failed to create event tap")
        }
    }

    private func handleEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
        eventCallback(event)
    }
}
