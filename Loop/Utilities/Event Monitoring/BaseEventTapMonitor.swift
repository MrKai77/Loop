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
    private static let teardownTimeout: DispatchTimeInterval = .milliseconds(250)

    let id = UUID()

    private var eventTap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var runLoopSource: CFRunLoopSource?
    private var readableIdentifier: String?
    private(set) var isEnabled: Bool = false

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

        if let readableIdentifier {
            log.info("Starting BaseEventTapMonitor '\(readableIdentifier)'")
        } else {
            log.info("Starting BaseEventTapMonitor with ID \(id)")
        }

        CGEvent.tapEnable(tap: eventTap, enable: true)
        isEnabled = true
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

    private func tearDownEventTap() {
        guard eventTap != nil || runLoopSource != nil else { return }

        let eventTap = eventTap
        let runLoop = runLoop
        let runLoopSource = runLoopSource
        let readableIdentifier = readableIdentifier

        self.eventTap = nil
        self.runLoop = nil
        self.runLoopSource = nil
        isEnabled = false

        let cleanup = {
            if let eventTap, CFMachPortIsValid(eventTap) {
                CGEvent.tapEnable(tap: eventTap, enable: false)
            }

            if let runLoop, let runLoopSource, CFRunLoopSourceIsValid(runLoopSource) {
                CFRunLoopRemoveSource(runLoop, runLoopSource, .commonModes)
            }

            if let eventTap, CFMachPortIsValid(eventTap) {
                CFMachPortInvalidate(eventTap)
            }
        }

        guard let runLoop else {
            cleanup()
            return
        }

        if CFRunLoopGetCurrent() == runLoop {
            cleanup()
            return
        }

        let finished = DispatchSemaphore(value: 0)
        let monitor = self
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
            cleanup()

            // Keep callback userInfo valid until the tap is torn down
            _ = monitor

            finished.signal()
        }
        CFRunLoopWakeUp(runLoop)

        if finished.wait(timeout: .now() + Self.teardownTimeout) == .timedOut {
            if let eventTap, CFMachPortIsValid(eventTap) {
                CGEvent.tapEnable(tap: eventTap, enable: false)
                CFMachPortInvalidate(eventTap)
            }

            let identifier = readableIdentifier ?? id.uuidString
            log.warn("Timed out while tearing down event tap '\(identifier)'. Invalidated it from the caller thread.")
        }
    }
}
