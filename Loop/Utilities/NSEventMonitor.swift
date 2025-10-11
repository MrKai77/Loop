//
//  NSEventMonitor.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-10.
//

import Cocoa
import OSLog

@available(*, deprecated, renamed: "PassiveEventMonitor", message: "Use a passive CGEvent monitor to receive events before it reaches the application level.")
final class NSEventMonitor: Identifiable, Equatable {
    let id = UUID()
    private let logger = Logger(category: "NSEventMonitor")

    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    private let scope: NSEventMonitor.Scope
    private let eventTypeMask: NSEvent.EventTypeMask
    private let eventHandler: (NSEvent) -> (NSEvent?)

    private(set) var isEnabled: Bool = false

    init(
        scope: Scope,
        eventMask: NSEvent.EventTypeMask,
        handler: @escaping (NSEvent) -> (NSEvent?)
    ) {
        self.eventTypeMask = eventMask
        self.eventHandler = handler
        self.scope = scope
    }

    deinit {
        if isEnabled {
            stop()
        }

        // Clear references
        localEventMonitor = nil
        globalEventMonitor = nil
    }

    func start() {
        guard !isEnabled else { return }

        // swiftformat:disable:next redundantSelf
        logger.info("Starting NSEventMonitor with ID \(self.id) and scope \(self.scope)")

        if scope.requiresLocalMonitor {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(
                matching: eventTypeMask,
                handler: { [weak self] event in
                    self?.eventHandler(event)
                }
            )
        }

        if scope.requiresGlobalMonitor {
            globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: eventTypeMask,
                handler: { [weak self] event in
                    _ = self?.eventHandler(event)
                }
            )
        }

        isEnabled = true
    }

    func stop() {
        guard isEnabled else { return }

        // swiftformat:disable:next redundantSelf
        logger.info("Stopping NSEventMonitor with ID \(self.id) and scope \(self.scope)")

        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }

        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }

        isEnabled = false
    }

    static func == (lhs: NSEventMonitor, rhs: NSEventMonitor) -> Bool {
        lhs.id == rhs.id
    }
}

extension NSEventMonitor {
    enum Scope: String, CustomStringConvertible {
        case local
        case global
        case all

        var description: String { rawValue }
        var requiresLocalMonitor: Bool { self == .local || self == .all }
        var requiresGlobalMonitor: Bool { self == .global || self == .all }
    }
}
