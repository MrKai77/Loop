//
//  PickerListEventMonitorManager.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-06.
//

import AppKit

final class PickerListEventMonitorManager {
    @MainActor static let shared: PickerListEventMonitorManager = .init()
    private var monitors: [AnyHashable: LocalEventMonitor] = [:]

    func addMonitor(
        for id: AnyHashable,
        matching mask: NSEvent.EventTypeMask,
        handler: @escaping (NSEvent) -> NSEvent?
    ) {
        removeMonitor(for: id)

        let monitor = LocalEventMonitor(
            events: mask,
            handler: handler
        )
        monitor.start()

        monitors[id] = monitor
    }

    func removeMonitor(for id: AnyHashable) {
        guard let monitor = monitors.removeValue(forKey: id) else { return }
        monitor.stop()
    }

    func removeAllMonitors() {
        monitors.forEach { $0.value.stop() }
        monitors.removeAll()
    }
}
