//
//  DataPatcher.swift
//  Loop
//
//  Created by Kai Azim on 2025-09-07.
//

import Defaults
import Foundation
import OSLog

enum DataPatcher {
    private static let logger = Logger(category: "DataPatcher")

    static func run() {
        let initialPatches = Defaults[.patchesApplied]

        if !initialPatches.contains(.accentColorMode) {
            // Migrate to accent color mode
            // We need to migrate `useSystemAccentColor` and `processWallpaper` over to `accentColorMode`
            if Defaults[.useSystemAccentColor] {
                Defaults[.accentColorMode] = .system
            } else if Defaults[.processWallpaper] {
                Defaults[.accentColorMode] = .wallpaper
            } else {
                Defaults[.accentColorMode] = .custom
            }

            Defaults[.patchesApplied].formUnion(.accentColorMode)
            logger.info("DataPatcher: Ran patch accentColorMode")
        }
    }

    struct Patch: OptionSet, Defaults.Serializable {
        let rawValue: Int

        static let accentColorMode = Self(rawValue: 1 << 0)
    }
}
