//
//  LocalEventMonitor.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-10.
//

import Cocoa
import Scribe

final class LocalEventMonitor: Identifiable, Equatable {
    let id = UUID()

    private var localEventMonitor: Any?
    private let eventTypeMask: NSEvent.EventTypeMask
    private let eventHandler: (NSEvent) -> (NSEvent?)

    private(set) var isEnabled: Bool = false

    /// Initializes a `LocalEventMonitor`.
    /// - Parameters:
    ///   - events: the events to capture within this event monitor.
    ///   - handler: how to handle the event. Return `nil` if processed, or the event itself to let the event continue through other event monitors.
    init(
        events: NSEvent.EventTypeMask,
        handler: @escaping (NSEvent) -> (NSEvent?)
    ) {
        self.eventTypeMask = events
        self.eventHandler = handler
    }

    deinit {
        if isEnabled {
            stop()
        }

        // Clear references
        localEventMonitor = nil
    }

    func start() {
        guard !isEnabled else { return }

        // swiftformat:disable:next redundantSelf
        Log.info("Starting LocalEventMonitor with ID \(self.id)", category: .localEventMonitor)

        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: eventTypeMask,
            handler: { [weak self] event in
                self?.eventHandler(event)
            }
        )

        isEnabled = true
    }

    func stop() {
        guard isEnabled else { return }

        // swiftformat:disable:next redundantSelf
        Log.info("Stopping LocalEventMonitor with ID \(self.id)", category: .localEventMonitor)

        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }

        isEnabled = false
    }

    static func == (lhs: LocalEventMonitor, rhs: LocalEventMonitor) -> Bool {
        lhs.id == rhs.id
    }
}
