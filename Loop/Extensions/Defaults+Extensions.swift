//
//  Defaults+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import SwiftUI
import Defaults

// Add variables for default values (which are stored even then the app is closed)
extension Defaults.Keys {
    static let launchAtLogin = Key<Bool>("launchAtLogin", default: false)
    static let currentIcon = Key<String>("currentIcon", default: "AppIcon-Default")
    static let timesLooped = Key<Int>("timesLooped", default: 0)
    static let isAccessibilityAccessGranted = Key<Bool>("isAccessibilityAccessGranted", default: false)

    static let useSystemAccentColor = Key<Bool>("useSystemAccentColor", default: false)
    static let accentColor = Key<Color>("accentColor", default: Color(.white))
    static let useGradientAccentColor = Key<Bool>("useGradientAccentColor", default: false)
    static let gradientAccentColor = Key<Color>("gradientAccentColor", default: Color(.black))

    static let triggerKey = Key<UInt16>("triggerKey", default: KeyCode.function)
    static let radialMenuCornerRadius = Key<CGFloat>("radialMenuCornerRadius", default: 50)
    static let radialMenuThickness = Key<CGFloat>("radialMenuThickness", default: 22)

    static let previewVisibility = Key<Bool>("previewVisibility", default: true)
    static let previewCornerRadius = Key<CGFloat>("previewCornerRadius", default: 15)
    static let previewPadding = Key<CGFloat>("previewPadding", default: 10)
    static let previewBorderThickness = Key<CGFloat>("previewBorderThickness", default: 0)

    static let maximizeKeybind = Key<[Set<UInt16>]>(
        "maximizeKeybind",
        default: [[KeyCode.space], [KeyCode.return]]
    )

    // Halves
    static let topHalfKeybind = Key<[Set<UInt16>]>(
        "topHalfKeybind",
        default: [[KeyCode.w], [KeyCode.upArrow]]
    )
    static let bottomHalfKeybind = Key<[Set<UInt16>]>(
        "bottomHalfKeybind",
        default: [[KeyCode.s], [KeyCode.downArrow]]
    )
    static let rightHalfKeybind = Key<[Set<UInt16>]>(
        "rightHalfKeybind",
        default: [[KeyCode.d], [KeyCode.rightArrow]]
    )
    static let leftHalfKeybind = Key<[Set<UInt16>]>(
        "leftHalfKeybind",
        default: [[KeyCode.a], [KeyCode.leftArrow]]
    )

    // Quarters
    static let topLeftQuarter = Key<[Set<UInt16>]>(
        "topLeftQuarter",
        default: [[KeyCode.w, KeyCode.a],
                  [KeyCode.upArrow, KeyCode.leftArrow]]
    )
    static let topRightQuarter = Key<[Set<UInt16>]>(
        "topRightQuarter",
        default: [[KeyCode.w, KeyCode.d],
                  [KeyCode.upArrow, KeyCode.rightArrow]]
    )
    static let bottomRightQuarter = Key<[Set<UInt16>]>(
        "bottomRightQuarter",
        default: [[KeyCode.s, KeyCode.d],
                  [KeyCode.downArrow, KeyCode.rightArrow]]
    )
    static let bottomLeftQuarter = Key<[Set<UInt16>]>(
        "bottomLeftQuarter",
        default: [[KeyCode.s, KeyCode.a],
                  [KeyCode.downArrow, KeyCode.leftArrow]]
    )

    // Thirds
    static let leftThird = Key<[Set<UInt16>]>(
        "leftThird",
        default: [[KeyCode.j]]
    )
    static let leftTwoThirds = Key<[Set<UInt16>]>(
        "leftTwoThirds",
        default: [[KeyCode.u]]
    )
    static let horizontalCenterThird = Key<[Set<UInt16>]>(
        "horizontalCenterThird",
        default: [[KeyCode.k]]
    )
    static let rightTwoThirds = Key<[Set<UInt16>]>(
        "rightTwoThirds",
        default: [[KeyCode.o]]
    )
    static let rightThird = Key<[Set<UInt16>]>(
        "rightThird",
        default: [[KeyCode.l]]
    )
}
