//
//  SoftwareUpdater.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-10.
//

import Foundation
import Sparkle
import Defaults

class SoftwareUpdater: NSObject, ObservableObject, SPUUpdaterDelegate {
    private var updater: SPUUpdater?
    private var automaticallyChecksForUpdatesObservation: NSKeyValueObservation?
    private var lastUpdateCheckDateObservation: NSKeyValueObservation?

    @Published var automaticallyChecksForUpdates = false {
        didSet {
            updater?.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    @Published var lastUpdateCheckDate: Date?

    private var feedURLTask: Task<(), Never>?

    override init() {
        super.init()
        updater = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        ).updater

        automaticallyChecksForUpdatesObservation = updater?.observe(
            \.automaticallyChecksForUpdates,
            options: [.initial, .new, .old]
        ) { [weak self] updater, change in
            guard change.newValue != change.oldValue else { return }
            self?.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        }

        lastUpdateCheckDateObservation = updater?.observe(
            \.lastUpdateCheckDate,
            options: [.initial, .new, .old]
        ) { [weak self] updater, _ in
            self?.lastUpdateCheckDate = updater.lastUpdateCheckDate
        }
    }

    deinit {
        feedURLTask?.cancel()
    }

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        Defaults[.includeDevelopmentVersions] ? ["development"] : []
    }

    func checkForUpdates() {
        updater?.checkForUpdates()
    }
}

extension URL {
    static var appcast = URL(
        string: "https://mrkai77.github.io/Loop/appcast.xml"
    )!
}
