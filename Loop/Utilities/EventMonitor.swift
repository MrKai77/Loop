//
//  EventMonitor.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-07.
//

import CoreGraphics
import OSLog

/// Base class to share common functionality. DO NOT USE DIRECTLY!
class BaseEventMonitor: Identifiable, Equatable {
    let id = UUID()
    private let logger = Logger(category: "BaseCGEventMonitor")

    private var eventTap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isEnabled: Bool = false

    /// Prevent class from being initialized outside of this file
    fileprivate init() {}

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

    fileprivate func setupRunLoopSource(eventTap: CFMachPort, runLoop: CFRunLoop) {
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

    static func == (lhs: BaseEventMonitor, rhs: BaseEventMonitor) -> Bool {
        lhs.id == rhs.id
    }
}

/// Active event monitor that can process and alter events when needed.
final class ActiveEventMonitor: BaseEventMonitor {
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
    ///   - callback: A callback to process receieved events. Return `forward` to pass the event along, `ignore` to block the event from reaching downstream receivers.
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
    ///   - callback: A callback to process and potentially alter receieved events.
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
            Unmanaged<Self>.fromOpaque(userInfo).release()
        }
    }

    private func handleEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
        eventCallback(event)
    }
}

/// Passive monitor that only listens to events.
/// Callback will be called on a separate thread to keep the CFMachPort's callback fast.
final class PassiveEventMonitor: BaseEventMonitor {
    private let eventCallback: (CGEvent) -> ()

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
            Unmanaged<Self>.fromOpaque(userInfo).release()
        }
    }

    private func handleEvent(event: CGEvent) {
        Task {
            eventCallback(event)
        }
    }
}
