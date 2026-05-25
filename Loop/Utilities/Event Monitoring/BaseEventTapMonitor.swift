//
//  BaseEventTapMonitor.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-07.
//

import CoreGraphics
import Foundation
import Scribe

/// Base class to share common functionality. DO NOT USE DIRECTLY!
@Loggable
class BaseEventTapMonitor: EventMonitorProtocol, Identifiable, Equatable {
    // Allow at most 5 restarts within any 2 second window before giving up
    private static let restartWindow: Duration = .seconds(2)
    private static let maxRestartsInWindow = 5

    let id = UUID()

    private var eventTap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var runLoopSource: CFRunLoopSource?
    private var readableIdentifier: String?
    private(set) var isEnabled: Bool = false

    private var restartTimestamps: [ContinuousClock.Instant] = []

    deinit {
        tearDownEventTap()
    }

    func setupRunLoopSource(eventTap: CFMachPort, readableIdentifier: String) {
        let runLoop = EventTapThread.shared.runLoop
        self.readableIdentifier = readableIdentifier

        if let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) {
            self.eventTap = eventTap
            self.runLoop = runLoop
            self.runLoopSource = runLoopSource
            CFRunLoopAddSource(runLoop, runLoopSource, .commonModes)
            CFRunLoopWakeUp(runLoop)
        }
    }

    func start() {
        guard let eventTap else { return }

        guard CFMachPortIsValid(eventTap) else {
            let identifier = readableIdentifier ?? id.uuidString
            log.warn("Event tap '\(identifier)' mach port is invalid, tearing down")
            tearDownEventTap()
            return
        }

        isEnabled = true

        if let readableIdentifier {
            log.info("Starting BaseEventTapMonitor '\(readableIdentifier)'")
        } else {
            log.info("Starting BaseEventTapMonitor with ID \(id)")
        }

        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        guard eventTap != nil else { return }

        if let readableIdentifier {
            log.info("Stopping BaseEventTapMonitor '\(readableIdentifier)'")
        } else {
            log.info("Stopping BaseEventTapMonitor with ID \(id)")
        }

        tearDownEventTap()
    }

    static func == (lhs: BaseEventTapMonitor, rhs: BaseEventTapMonitor) -> Bool {
        lhs.id == rhs.id
    }

    /// Attempts to re-enable the tap after a timeout, giving up if it's restarting too frequently.
    func attemptRestart() {
        let now = ContinuousClock.now
        let windowStart = now - Self.restartWindow
        restartTimestamps.removeAll { $0 < windowStart }
        restartTimestamps.append(now)

        let identifier = readableIdentifier ?? id.uuidString

        if restartTimestamps.count > Self.maxRestartsInWindow {
            log.warn("Event tap '\(identifier)' restart cascade detected, tearing down")
            tearDownEventTap()
            return
        }

        start()
    }

    private func tearDownEventTap() {
        guard eventTap != nil || runLoopSource != nil else { return }

        let eventTap = eventTap
        let runLoop = runLoop
        let runLoopSource = runLoopSource

        self.eventTap = nil
        self.runLoop = nil
        self.runLoopSource = nil
        isEnabled = false

        if let eventTap, CFMachPortIsValid(eventTap) {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }

        guard let runLoop, let runLoopSource else { return }

        // Keep the tap callback's refcon pointer valid until any in-flight callback finishes
        let monitor = self
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes as CFTypeRef) {
            CFRunLoopRemoveSource(runLoop, runLoopSource, .commonModes)
            _ = monitor
        }
        CFRunLoopWakeUp(runLoop)
    }
}
