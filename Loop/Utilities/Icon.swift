//
//  Icon.swift
//  Loop
//
//  Created by Kai Azim on 2024-06-07.
//

import Luminare
import SwiftUI

/// Unlock Flow:
/// - Developer: 0 Loops **(Debug builds only)**
/// - Classic: 0 Loops
/// - Holo: 25 Loops
/// - Rosé Pine: 50 Loops
/// - Meta Loop: 100 Loops
/// - Keycap: 200 Loops
/// - White: 400 Loops
/// - Black: 500 Loops
/// - Daylight: 1000 Loops
/// - Neon: 1500 Loops
/// - Synthwave Sunset: 2000 Loops
/// - Black Hole: 2500 Loops
/// - Summer: 3000 Loops
/// - Master: 5000 Loops

struct Icon: Hashable, LuminareSelectionData {
    var name: String
    var assetName: String
    var unlockTime: Int
    var unlockMessage: String?

    var isSelectable: Bool {
        IconManager.returnUnlockedIcons().contains(self)
    }

    #if DEBUG
        static let all: [Icon] = [
            .developer,
            .classic,
            .holo,
            .rosePine,
            .metaLoop,
            .keycap,
            .white,
            .black,
            .daylight,
            .neon,
            .synthwaveSunset,
            .blackHole,
            .summer,
            .master
        ]

        static let `default` = Icon.developer
    #else
        static let all: [Icon] = [
            .classic,
            .holo,
            .rosePine,
            .metaLoop,
            .keycap,
            .white,
            .black,
            .daylight,
            .neon,
            .synthwaveSunset,
            .blackHole,
            .summer,
            .master
        ]

        static let `default` = Icon.classic
    #endif
}

// MARK: - Kai Azim

extension Icon {
    static let classic = Icon(
        name: .init(localized: .init("Icon Name: Classic", defaultValue: "Classic")),
        assetName: "AppIcon-Classic",
        unlockTime: 0
    )
    static let holo = Icon(
        name: .init(localized: .init("Icon Name: Holo", defaultValue: "Holo")),
        assetName: "AppIcon-Holo",
        unlockTime: 25,
        unlockMessage: .init(
            localized: .init(
                "Icon Unlock Message: Holo",
                defaultValue: """
                You've already looped 25 times! As a reward, here's new icon: \(.init(localized: .init("Icon Name: Holo", defaultValue: "Holo"))). Continue to loop more to unlock new icons!
                """
            )
        )
    )
    static let rosePine = Icon(
        name: .init(localized: .init("Icon Name: Rosé Pine", defaultValue: "Rosé Pine")),
        assetName: "AppIcon-Rose Pine",
        unlockTime: 50
    )
    static let metaLoop = Icon(
        name: .init(localized: .init("Icon Name: Meta Loop", defaultValue: "Meta Loop")),
        assetName: "AppIcon-Meta Loop",
        unlockTime: 100
    )
    static let keycap = Icon(
        name: .init(localized: .init("Icon Name: Keycap", defaultValue: "Keycap")),
        assetName: "AppIcon-Keycap",
        unlockTime: 200
    )
    static let white = Icon(
        name: .init(localized: .init("Icon Name: White", defaultValue: "White")),
        assetName: "AppIcon-White",
        unlockTime: 400
    )
    static let black = Icon(
        name: .init(localized: .init("Icon Name: Black", defaultValue: "Black")),
        assetName: "AppIcon-Black",
        unlockTime: 500
    )
    static let master = Icon(
        name: .init(localized: .init("Icon Name: Loop Master", defaultValue: "Loop Master")),
        assetName: "AppIcon-Loop Master",
        unlockTime: 5000,
        unlockMessage: .init(
            localized: .init(
                "Icon Unlock Message: Loop Master",
                defaultValue: "5000 loops conquered! The universe has witnessed the birth of a Loop master! Enjoy your well-deserved reward: a brand-new icon!"
            )
        )
    )
}

// MARK: - Greg Lassale

extension Icon {
    static let neon = Icon(
        name: .init(localized: .init("Icon Name: Neon", defaultValue: "Neon")),
        assetName: "AppIcon-Neon",
        unlockTime: 1500
    )
    static let synthwaveSunset = Icon(
        name: .init(localized: .init("Icon Name: Synthwave Sunset", defaultValue: "Synthwave Sunset")),
        assetName: "AppIcon-Synthwave Sunset",
        unlockTime: 2000
    )
    static let blackHole = Icon(
        name: .init(localized: .init("Icon Name: Black Hole", defaultValue: "Black Hole")),
        assetName: "AppIcon-Black Hole",
        unlockTime: 2500
    )
}

// MARK: - JSDev

extension Icon {
    static let developer = Icon(
        name: .init(localized: .init("Icon Name: Developer", defaultValue: "Developer")),
        assetName: "AppIcon-Developer",
        unlockTime: 0
    )

    static let summer = Icon(
        name: .init(localized: .init("Icon Name: Summer", defaultValue: "Summer")),
        assetName: "AppIcon-Summer",
        unlockTime: 3000
    )
}

// MARK: - 0w0x

extension Icon {
    static let daylight = Icon(
        name: .init(localized: .init("Icon Name: Daylight", defaultValue: "Daylight")),
        assetName: "AppIcon-Daylight",
        unlockTime: 1000
    )
}
