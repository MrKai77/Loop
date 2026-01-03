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
        let initialPatches: Patches = Defaults[.patchesApplied]

        runPatch(patch: .changeToAccentColorMode, initial: initialPatches) {
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

            Defaults.reset(.useSystemAccentColor)
            Defaults.reset(.processWallpaper)
        }

        runPatch(patch: .removeRevealedStashedWindows, initial: initialPatches) {
            Defaults.reset(.stashManagerRevealedWindows)
        }
    }

    private static func runPatch(patch: Patches, initial: Patches, with callback: () -> ()) {
        if !initial.contains(patch) {
            callback()

            Defaults[.patchesApplied].formUnion(patch)
            Log.info("Ran patch \(patch)", category: .dataPatcher)
        }
    }

    struct Patches: OptionSet, Defaults.Serializable {
        let rawValue: Int

        static let changeToAccentColorMode = Self(rawValue: 1 << 0)
        static let removeRevealedStashedWindows = Self(rawValue: 1 << 1)
    }
}
