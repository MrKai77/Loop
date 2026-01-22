//
//  LaunchAtLoginManager.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-21.
//

import Defaults
import Scribe
import ServiceManagement

@Loggable
@MainActor
final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    private var observationTask: Task<(), Never>?

    private init() {
        self.observationTask = Task { [weak self] in
            for await launchAtLogin in Defaults.updates(.launchAtLogin, initial: false) {
                guard !Task.isCancelled, let self else { break }
                await setLaunchAtLogin(launchAtLogin)
            }
        }
    }

    deinit {
        observationTask?.cancel()
    }

    func start() {
        Task {
            await setLaunchAtLogin(Defaults[.launchAtLogin])
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) async {
        let currentlyEnabled = SMAppService.mainApp.status == .enabled
        guard enabled != currentlyEnabled else {
            return
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
                log.info("Registered login item")
            } else {
                try await SMAppService.mainApp.unregister()
                log.info("Unregistered login item")
            }
        } catch {
            log.error("Failed to \(enabled ? "register" : "unregister") login item: \(error.localizedDescription)")
        }
    }
}
