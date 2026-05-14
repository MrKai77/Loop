//
//  EventTapThread.swift
//  Loop
//
//  Created by Kai Azim on 2026-05-06.
//

import CoreFoundation
import Foundation

/// Owns the run loop used by global event taps.
final class EventTapThread: Thread {
    static let shared = EventTapThread(name: "\(Bundle.main.bundleID).EventTapThread")

    private let startLock = NSLock()
    private let runLoopReady = DispatchGroup()
    private var hasStarted = false
    private var eventTapRunLoop: CFRunLoop?

    var runLoop: CFRunLoop {
        startLock.lock()
        if !hasStarted {
            hasStarted = true
            start()
        }
        startLock.unlock()

        runLoopReady.wait()

        guard let eventTapRunLoop else {
            preconditionFailure("EventTapThread failed to publish its run loop")
        }

        return eventTapRunLoop
    }

    private init(name: String) {
        runLoopReady.enter()
        super.init()
        self.name = name
        qualityOfService = .userInteractive
    }

    override func main() {
        eventTapRunLoop = CFRunLoopGetCurrent()

        var sourceContext = CFRunLoopSourceContext()
        let keepAliveSource = CFRunLoopSourceCreate(
            kCFAllocatorDefault,
            0,
            &sourceContext
        )

        if let eventTapRunLoop, let keepAliveSource {
            CFRunLoopAddSource(eventTapRunLoop, keepAliveSource, .commonModes)
        }

        runLoopReady.leave()
        CFRunLoopRun()
    }
}
