//
//  MultitouchGestureBlocker.swift
//  Loop
//
//  Created by Kai Azim on 2026-04-05.
//

import AppKit
import Scribe

@Loggable
final class MultitouchGestureBlocker {
    private var monitor: ActiveEventMonitor?

    func start() {
        stop()
        log.info("Starting gesture blocker")

        let eventTypes: [CGEventType] = [
            .scrollWheel,
            CGEventType(rawValue: UInt32(NSEvent.EventType.gesture.rawValue)),
            CGEventType(rawValue: UInt32(NSEvent.EventType.magnify.rawValue)),
            CGEventType(rawValue: UInt32(NSEvent.EventType.rotate.rawValue)),
            CGEventType(rawValue: UInt32(NSEvent.EventType.smartMagnify.rawValue))
        ].compactMap(\.self)

        monitor = ActiveEventMonitor("gesture_blocker", events: eventTypes) { _ in .ignore }
        monitor?.start()
    }

    func stop() {
        monitor?.stop()
        monitor = nil

        log.info("Stopped gesture blocker")
    }
}
