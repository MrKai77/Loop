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

    static let triggerKey = Key<CGKeyCode>("triggerKey", default: .kVK_Function)
    static let radialMenuCornerRadius = Key<CGFloat>("radialMenuCornerRadius", default: 50)
    static let radialMenuThickness = Key<CGFloat>("radialMenuThickness", default: 22)

    static let previewVisibility = Key<Bool>("previewVisibility", default: true)
    static let previewCornerRadius = Key<CGFloat>("previewCornerRadius", default: 10)
    static let previewPadding = Key<CGFloat>("previewPadding", default: 10)
    static let previewBorderThickness = Key<CGFloat>("previewBorderThickness", default: 5)

    static let maximizeKeybind = Key<[Set<CGKeyCode>]>(
        "maximizeKeybind",
        default: [[.kVK_Space], [.kVK_Return]]
    )

    // Halves
    static let topHalfKeybind = Key<[Set<UInt16>]>(
        "topHalfKeybind",
        default: [[.kVK_ANSI_W], [.kVK_UpArrow]]
    )
    static let bottomHalfKeybind = Key<[Set<UInt16>]>(
        "bottomHalfKeybind",
        default: [[.kVK_ANSI_S], [.kVK_DownArrow]]
    )
    static let rightHalfKeybind = Key<[Set<UInt16>]>(
        "rightHalfKeybind",
        default: [[.kVK_ANSI_D], [.kVK_RightArrow]]
    )
    static let leftHalfKeybind = Key<[Set<UInt16>]>(
        "leftHalfKeybind",
        default: [[.kVK_ANSI_A], [.kVK_LeftArrow]]
    )

    // Quarters
    static let topLeftQuarter = Key<[Set<UInt16>]>(
        "topLeftQuarter",
        default: [[.kVK_ANSI_W, .kVK_ANSI_A],
                  [.kVK_UpArrow, .kVK_LeftArrow]]
    )
    static let topRightQuarter = Key<[Set<UInt16>]>(
        "topRightQuarter",
        default: [[.kVK_ANSI_W, .kVK_ANSI_D],
                  [.kVK_UpArrow, .kVK_RightArrow]]
    )
    static let bottomRightQuarter = Key<[Set<UInt16>]>(
        "bottomRightQuarter",
        default: [[.kVK_ANSI_S, .kVK_ANSI_D],
                  [.kVK_DownArrow, .kVK_RightArrow]]
    )
    static let bottomLeftQuarter = Key<[Set<UInt16>]>(
        "bottomLeftQuarter",
        default: [[.kVK_ANSI_S, .kVK_ANSI_A],
                  [.kVK_DownArrow, .kVK_LeftArrow]]
    )

    // Thirds
    static let leftThird = Key<[Set<UInt16>]>(
        "leftThird",
        default: [[.kVK_ANSI_J]]
    )
    static let leftTwoThirds = Key<[Set<UInt16>]>(
        "leftTwoThirds",
        default: [[.kVK_ANSI_U]]
    )
    static let horizontalCenterThird = Key<[Set<UInt16>]>(
        "horizontalCenterThird",
        default: [[.kVK_ANSI_K]]
    )
    static let rightTwoThirds = Key<[Set<UInt16>]>(
        "rightTwoThirds",
        default: [[.kVK_ANSI_O]]
    )
    static let rightThird = Key<[Set<UInt16>]>(
        "rightThird",
        default: [[.kVK_ANSI_L]]
    )
}
