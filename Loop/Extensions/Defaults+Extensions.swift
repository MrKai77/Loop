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
    static let enableTrackpadHapticFeedback = Defaults.Key<Bool>("enableTrackpadHapticFeedback", default: true)
    static let launchAtLogin = Key<Bool>("launchAtLogin", default: false)
    static let hideMenuBarIcon = Key<Bool>("hideMenuBarIcon", default: false)
    static let currentIcon = Key<String>("currentIcon", default: "AppIcon-Classic")
    static let notificationWhenIconUnlocked = Key<Bool>("notificationWhenIconUnlocked", default: true)
    static let timesLooped = Key<Int>("timesLooped", default: 0)
    static let windowSnapping = Key<Bool>("windowSnapping", default: false) // BETA
    static let animateWindowResizes = Key<Bool>("animateWindowResizes", default: false) // BETA
    static let windowPadding = Key<CGFloat>("windowPadding", default: 0)
    static let restoreWindowFrameOnDrag = Key<Bool>("restoreWindowFrameOnDrag", default: true)
    static let resizeWindowUnderCursor = Key<Bool>("resizeWindowUnderCursor", default: false)

    static let animationConfiguration = Key<AnimationConfiguration>("animationConfiguration", default: .smooth)

    static let useSystemAccentColor = Key<Bool>("useSystemAccentColor", default: true)
    static let customAccentColor = Key<Color>("customAccentColor", default: Color(.white))
    static let useGradient = Key<Bool>("useGradient", default: true)
    static let gradientColor = Key<Color>("gradientColor", default: Color(.black))

    static let radialMenuCornerRadius = Key<CGFloat>("radialMenuCornerRadius", default: 50)
    static let radialMenuThickness = Key<CGFloat>("radialMenuThickness", default: 22)
    static let hideUntilDirectionIsChosen = Key<Bool>("hideUntilDirectionIsChosen", default: false)

    static let triggerKey = Key<Set<CGKeyCode>>("trigger", default: [.kVK_Function])
    static let doubleClickToTrigger = Key<Bool>("doubleClickToTrigger", default: false)
    static let triggerDelay = Key<Float>("triggerDelay", default: 0)
    static let middleClickTriggersLoop = Key<Bool>("middleClickTriggersLoop", default: false)

    static let previewVisibility = Key<Bool>("previewVisibility", default: true)
    static let previewCornerRadius = Key<CGFloat>("previewCornerRadius", default: 10)
    static let previewPadding = Key<CGFloat>("previewPadding", default: 10)
    static let previewBorderThickness = Key<CGFloat>("previewBorderThickness", default: 5)

    static let keybinds = Key<[WindowAction]>("keybinds", default: [
        WindowAction(.maximize, keybind: [.kVK_Space]),
        WindowAction(.center, keybind: [.kVK_Return]),
        WindowAction(.cycleTop, keybind: [.kVK_UpArrow]),
        WindowAction(.cycleBottom, keybind: [.kVK_DownArrow]),
        WindowAction(.cycleLeft, keybind: [.kVK_LeftArrow]),
        WindowAction(.cycleRight, keybind: [.kVK_RightArrow]),

        WindowAction(.topLeftQuarter, keybind: [.kVK_UpArrow, .kVK_LeftArrow]),
        WindowAction(.topRightQuarter, keybind: [.kVK_UpArrow, .kVK_RightArrow]),
        WindowAction(.bottomRightQuarter, keybind: [.kVK_DownArrow, .kVK_RightArrow]),
        WindowAction(.bottomLeftQuarter, keybind: [.kVK_DownArrow, .kVK_LeftArrow])
    ])

    static let respectStageManager = Key<Bool>("respectStageManager", default: true)
    static let stageStripSize = Key<CGFloat>("stageStripSize", default: 150)
}
