//
//  DataPatcher.swift
//  Loop
//
//  Created by Kai Azim on 2025-09-07.
//

import Defaults
import Foundation
import Scribe

enum DataPatcher {
    static func run() {
        let initialPatches = Defaults[.patchesApplied]

        if !initialPatches.contains(.accentColorMode) {
            // Migrate to accent color mode
            // We need to migrate `useSystemAccentColor` and `processWallpaper` over to `accentColorMode`
            let useSystemAccentColor: Bool = Defaults[.useSystemAccentColor]
            let processWallpaper: Bool = Defaults[.processWallpaper]

            if useSystemAccentColor {
                Defaults[.accentColorMode] = .system
            } else if processWallpaper {
                Defaults[.accentColorMode] = .wallpaper
            } else {
                Defaults[.accentColorMode] = .custom
            }

            Defaults[.patchesApplied].formUnion(.accentColorMode)
            Log.info("Ran patch accentColorMode", category: .dataPatcher)
        }
    }

    struct Patch: OptionSet, Defaults.Serializable {
        let rawValue: Int

        static let accentColorMode = Self(rawValue: 1 << 0)
    }
}
