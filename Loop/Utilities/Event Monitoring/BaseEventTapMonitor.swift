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

        self.eventTap = nil
        self.runLoop = nil
        self.runLoopSource = nil
        isEnabled = false

        guard let runLoop else {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: false)
                CFMachPortInvalidate(eventTap)
            }
            return
        }

        let cleanup = {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: false)
            }

            if let runLoopSource {
                CFRunLoopRemoveSource(runLoop, runLoopSource, .commonModes)
            }

            if let eventTap {
                CFMachPortInvalidate(eventTap)
            }
        }

        if CFRunLoopGetCurrent() == runLoop {
            cleanup()
            return
        }

        let finished = DispatchSemaphore(value: 0)
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
            cleanup()
            finished.signal()
        }
        CFRunLoopWakeUp(runLoop)
        finished.wait()
    }
}
