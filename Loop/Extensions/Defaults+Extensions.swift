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
    static let windowSnapping = Key<Bool>("windowSnapping", default: false) // BETA
    static let animateWindowResizes = Key<Bool>("animateWindowResizes", default: false) // BETA
    static let windowPadding = Key<CGFloat>("windowPadding", default: 0)

    static let animationConfiguration = Key<AnimationConfiguration>("animationConfiguration", default: .smooth)

    static let useSystemAccentColor = Key<Bool>("useSystemAccentColor", default: true)
    static let customAccentColor = Key<Color>("customAccentColor", default: Color(.white))
    static let useGradient = Key<Bool>("useGradient", default: true)
    static let gradientColor = Key<Color>("gradientColor", default: Color(.black))

    static let radialMenuCornerRadius = Key<CGFloat>("radialMenuCornerRadius", default: 50)
    static let radialMenuThickness = Key<CGFloat>("radialMenuThickness", default: 22)

    static let triggerKey = Key<TriggerKey>("trigger", default: TriggerKey.options[0])
    static let doubleClickToTrigger = Key<Bool>("doubleClickToTrigger", default: false)
    static let triggerDelay = Key<Float>("triggerDelay", default: 0)
    static let middleClickTriggersLoop = Key<Bool>("middleClickTriggersLoop", default: false)

    static let previewVisibility = Key<Bool>("previewVisibility", default: true)
    static let previewCornerRadius = Key<CGFloat>("previewCornerRadius", default: 10)
    static let previewPadding = Key<CGFloat>("previewPadding", default: 10)
    static let previewBorderThickness = Key<CGFloat>("previewBorderThickness", default: 5)

    static let preferMinimizeWithScrollDown = Key<Bool>("preferMinimizeWithScrollDown", default: false)

    static let keybinds = Key<[Keybind]>("keybinds", default: [
        Keybind(.maximize, keycode: [.kVK_Space]),
        Keybind(.center, keycode: [.kVK_Return]),
        Keybind(.cycleTop, keycode: [.kVK_UpArrow]),
        Keybind(.cycleBottom, keycode: [.kVK_DownArrow]),
        Keybind(.cycleLeft, keycode: [.kVK_LeftArrow]),
        Keybind(.cycleRight, keycode: [.kVK_RightArrow]),

        Keybind(.topLeftQuarter, keycode: [.kVK_UpArrow, .kVK_LeftArrow]),
        Keybind(.topRightQuarter, keycode: [.kVK_UpArrow, .kVK_RightArrow]),
        Keybind(.bottomRightQuarter, keycode: [.kVK_DownArrow, .kVK_RightArrow]),
        Keybind(.bottomLeftQuarter, keycode: [.kVK_DownArrow, .kVK_LeftArrow]),
    ])
}
