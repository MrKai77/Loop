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
    var retainedSelf: Unmanaged<BaseEventTapMonitor>?

    private var eventTap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isEnabled: Bool = false

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

        retainedSelf?.release()
        retainedSelf = nil
    }

    func setupRunLoopSource(eventTap: CFMachPort) {
        // Runloop is already running here. In the future, we can investigate running the mach port on another thread.
        let runLoop = CFRunLoopGetMain()

        if let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) {
            self.eventTap = eventTap
            self.runLoop = runLoop
            self.runLoopSource = runLoopSource
            CFRunLoopAddSource(runLoop, runLoopSource, .commonModes)
        }
    }

    func start() {
        guard let eventTap else { return }
        isEnabled = true

        log.info("Starting BaseEventTapMonitor with ID \(id)")

        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        guard let eventTap else { return }
        isEnabled = false

        log.info("Stopping BaseEventTapMonitor with ID \(id)")

        CGEvent.tapEnable(tap: eventTap, enable: false)
    }

    static func == (lhs: BaseEventTapMonitor, rhs: BaseEventTapMonitor) -> Bool {
        lhs.id == rhs.id
    }
}
