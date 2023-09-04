//
//  SoftwareUpdater.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-10.
//

import Foundation
import Sparkle

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

    @Published var includeDevelopmentVersions = false {
        didSet {
            UserDefaults.standard.setValue(includeDevelopmentVersions, forKey: "includeDevelopmentVersions")
        }
    }

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
            options: [.initial, .new, .old],
            changeHandler: { [unowned self] updater, change in
                guard change.newValue != change.oldValue else { return }
                self.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
            }
        )

        lastUpdateCheckDateObservation = updater?.observe(
            \.lastUpdateCheckDate,
            options: [.initial, .new, .old],
            changeHandler: { [unowned self] updater, _ in
                self.lastUpdateCheckDate = updater.lastUpdateCheckDate
            }
        )

        includeDevelopmentVersions = UserDefaults.standard.bool(forKey: "includePrereleaseVersions")
    }

    deinit {
        feedURLTask?.cancel()
    }

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        if includeDevelopmentVersions {
            return ["development"]
        }
        return []
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
