//
//  Icon.swift
//  Loop
//
//  Created by Kai Azim on 2024-06-07.
//

import Luminare
import SwiftUI

struct Icon: Hashable, LuminarePickerData {
    var name: String
    var iconName: String
    var unlockTime: Int
    var unlockMessage: String?

    var selectable: Bool {
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
            .simon,
            .neon,
            .synthwaveSunset,
            .blackHole,
            .summer,
            .master
        ]
    #else
        static let all: [Icon] = [
            .classic,
            .holo,
            .rosePine,
            .metaLoop,
            .keycap,
            .white,
            .black,
            .simon,
            .neon,
            .synthwaveSunset,
            .blackHole,
            .summer,
            .master
        ]
    #endif
}

// MARK: - Kai Azim

extension Icon {
    static let classic = Icon(
        name: .init(localized: .init("Icon Name: Classic", defaultValue: "Classic")),
        iconName: "AppIcon-Classic",
        unlockTime: 0
    )
    static let holo = Icon(
        name: .init(localized: .init("Icon Name: Holo", defaultValue: "Holo")),
        iconName: "AppIcon-Holo",
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
        iconName: "AppIcon-Rose Pine",
        unlockTime: 50
    )
    static let metaLoop = Icon(
        name: .init(localized: .init("Icon Name: Meta Loop", defaultValue: "Meta Loop")),
        iconName: "AppIcon-Meta Loop",
        unlockTime: 100
    )
    static let keycap = Icon(
        name: .init(localized: .init("Icon Name: Keycap", defaultValue: "Keycap")),
        iconName: "AppIcon-Keycap",
        unlockTime: 200
    )
    static let white = Icon(
        name: .init(localized: .init("Icon Name: White", defaultValue: "White")),
        iconName: "AppIcon-White",
        unlockTime: 400
    )
    static let black = Icon(
        name: .init(localized: .init("Icon Name: Black", defaultValue: "Black")),
        iconName: "AppIcon-Black",
        unlockTime: 500
    )
    static let master = Icon(
        name: .init(localized: .init("Icon Name: Loop Master", defaultValue: "Loop Master")),
        iconName: "AppIcon-Loop Master",
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
    static let simon = Icon(
        name: .init(localized: .init("Icon Name: Simon", defaultValue: "Simon")),
        iconName: "AppIcon-Simon",
        unlockTime: 1000
    )
    static let neon = Icon(
        name: .init(localized: .init("Icon Name: Neon", defaultValue: "Neon")),
        iconName: "AppIcon-Neon",
        unlockTime: 1500
    )
    static let synthwaveSunset = Icon(
        name: .init(localized: .init("Icon Name: Synthwave Sunset", defaultValue: "Synthwave Sunset")),
        iconName: "AppIcon-Synthwave Sunset",
        unlockTime: 2000
    )
    static let blackHole = Icon(
        name: .init(localized: .init("Icon Name: Black Hole", defaultValue: "Black Hole")),
        iconName: "AppIcon-Black Hole",
        unlockTime: 2500
    )
}

// MARK: - JSDev

extension Icon {
    static let developer = Icon(
        name: .init(localized: .init("Icon Name: Developer", defaultValue: "Developer")),
        iconName: "AppIcon-Developer",
        unlockTime: 0
    )

    static let summer = Icon(
        name: .init(localized: .init("Icon Name: Summer", defaultValue: "Summer")),
        iconName: "AppIcon-Summer",
        unlockTime: 3000
    )
}
