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
    static let currentIcon = Key<String>("currentIcon", default: "AppIcon-Classic")
    static let timesLooped = Key<Int>("timesLooped", default: 0)

    static let useSystemAccentColor = Key<Bool>("useSystemAccentColor", default: true)
    static let customAccentColor = Key<Color>("customAccentColor", default: Color(.white))
    static let useGradient = Key<Bool>("useGradient", default: true)
    static let gradientColor = Key<Color>("gradientColor", default: Color(.black))

    static let triggerKey = Key<TriggerKey>("trigger", default: TriggerKey.options[0])
    static let doubleClickToTrigger = Key<Bool>("doubleClickToTrigger", default: false)
    static let triggerDelay = Key<Float>("triggerDelay", default: 0)
    static let radialMenuCornerRadius = Key<CGFloat>("radialMenuCornerRadius", default: 50)
    static let radialMenuThickness = Key<CGFloat>("radialMenuThickness", default: 22)

    static let previewVisibility = Key<Bool>("previewVisibility", default: true)
    static let previewCornerRadius = Key<CGFloat>("previewCornerRadius", default: 10)
    static let previewPadding = Key<CGFloat>("previewPadding", default: 10)
    static let previewBorderThickness = Key<CGFloat>("previewBorderThickness", default: 5)

    static let maximizeKeybind = Key<[Set<CGKeyCode>]>(
        "maximizeKeybind",
        default: [[.kVK_Space]]
    )
    static let fullscreenKeybind = Key<[Set<CGKeyCode>]>(
        "fullscreenKeybind",
        default: [[.kVK_ANSI_F]]
    )
    static let centerKeybind = Key<[Set<CGKeyCode>]>(
        "centerKeybind",
        default: [[.kVK_Return]]
    )
    static let lastDirectionKeybind = Key<[Set<CGKeyCode>]>(
        "lastDirectionKeybind",
        default: [[.kVK_ANSI_Z]]
    )

    // Halves
    static let topHalfKeybind = Key<[Set<CGKeyCode>]>(
        "topHalfKeybind",
        default: [[.kVK_ANSI_W], [.kVK_UpArrow]]
    )
    static let bottomHalfKeybind = Key<[Set<CGKeyCode>]>(
        "bottomHalfKeybind",
        default: [[.kVK_ANSI_S], [.kVK_DownArrow]]
    )
    static let rightHalfKeybind = Key<[Set<CGKeyCode>]>(
        "rightHalfKeybind",
        default: [[.kVK_ANSI_D], [.kVK_RightArrow]]
    )
    static let leftHalfKeybind = Key<[Set<CGKeyCode>]>(
        "leftHalfKeybind",
        default: [[.kVK_ANSI_A], [.kVK_LeftArrow]]
    )

    // Quarters
    static let topLeftQuarter = Key<[Set<CGKeyCode>]>(
        "topLeftQuarter",
        default: [[.kVK_ANSI_W, .kVK_ANSI_A],
                  [.kVK_UpArrow, .kVK_LeftArrow]]
    )
    static let topRightQuarter = Key<[Set<CGKeyCode>]>(
        "topRightQuarter",
        default: [[.kVK_ANSI_W, .kVK_ANSI_D],
                  [.kVK_UpArrow, .kVK_RightArrow]]
    )
    static let bottomRightQuarter = Key<[Set<CGKeyCode>]>(
        "bottomRightQuarter",
        default: [[.kVK_ANSI_S, .kVK_ANSI_D],
                  [.kVK_DownArrow, .kVK_RightArrow]]
    )
    static let bottomLeftQuarter = Key<[Set<CGKeyCode>]>(
        "bottomLeftQuarter",
        default: [[.kVK_ANSI_S, .kVK_ANSI_A],
                  [.kVK_DownArrow, .kVK_LeftArrow]]
    )

    // Thirds
    static let leftThird = Key<[Set<CGKeyCode>]>(
        "leftThird",
        default: [[.kVK_ANSI_J]]
    )
    static let leftTwoThirds = Key<[Set<CGKeyCode>]>(
        "leftTwoThirds",
        default: [[.kVK_ANSI_J, .kVK_ANSI_K]]
    )
    static let horizontalCenterThird = Key<[Set<CGKeyCode>]>(
        "horizontalCenterThird",
        default: [[.kVK_ANSI_K]]
    )
    static let rightTwoThirds = Key<[Set<CGKeyCode>]>(
        "rightTwoThirds",
        default: [[.kVK_ANSI_K, .kVK_ANSI_L]]
    )
    static let rightThird = Key<[Set<CGKeyCode>]>(
        "rightThird",
        default: [[.kVK_ANSI_L]]
    )

    // BETA
    static let animateWindowResizes = Key<Bool>("animateWindowResizes", default: false)
    static let windowPadding = Key<CGFloat>("windowPadding", default: 0)
    static let windowSnapping = Key<Bool>("windowSnapping", default: false)
}
