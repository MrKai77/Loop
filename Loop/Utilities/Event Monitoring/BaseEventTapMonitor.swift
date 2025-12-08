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
class BaseEventTapMonitor: Identifiable, Equatable {
    let id = UUID()

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
    }

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
        Log.info("Starting BaseEventTapMonitor with ID \(self.id)", category: .baseEventTapMonitor)

        CGEvent.tapEnable(tap: eventTap, enable: true)
        isEnabled = true
    }

    func stop() {
        guard let eventTap else { return }

        // swiftformat:disable:next redundantSelf
        Log.info("Stopping BaseEventTapMonitor with ID \(self.id)", category: .baseEventTapMonitor)

        CGEvent.tapEnable(tap: eventTap, enable: false)
        isEnabled = false
    }

    static func == (lhs: BaseEventTapMonitor, rhs: BaseEventTapMonitor) -> Bool {
        lhs.id == rhs.id
    }
}
