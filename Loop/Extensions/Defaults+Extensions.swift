//
//  Defaults+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//
// NOTE: While iCloud is enabled, its service is currently disabled to make GitHub actions work.

import Defaults
import SwiftUI

// Add variables for default values (which are stored even then the app is closed)
extension Defaults.Keys {
    // Icon
    static let currentIcon = Key<String>("currentIcon", default: "AppIcon-Classic", iCloud: true)
    static let timesLooped = Key<Int>("timesLooped", default: 0, iCloud: true)
    static let showDockIcon = Key<Bool>("showDockIcon", default: false, iCloud: true)
    static let notificationWhenIconUnlocked = Key<Bool>("notificationWhenIconUnlocked", default: true, iCloud: true)

    // Accent Color
    static let useSystemAccentColor = Key<Bool>("useSystemAccentColor", default: true, iCloud: true)
    static let customAccentColor = Key<Color>("customAccentColor", default: Color(.white), iCloud: true)
    static let useGradient = Key<Bool>("useGradient", default: true, iCloud: true)
    static let gradientColor = Key<Color>("gradientColor", default: Color(.black), iCloud: true)
    static let processWallpaper = Key<Bool>("processWallpaper", default: false, iCloud: true)

    // Radial Menu
    static let radialMenuVisibility = Key<Bool>("radialMenuVisibility", default: true, iCloud: true)
    static let radialMenuCornerRadius = Key<CGFloat>("radialMenuCornerRadius", default: 50, iCloud: true)
    static let radialMenuThickness = Key<CGFloat>("radialMenuThickness", default: 22, iCloud: true)

    // Preview
    static let previewVisibility = Key<Bool>("previewVisibility", default: true, iCloud: true)
    static let previewPadding = Key<CGFloat>("previewPadding", default: 10, iCloud: true)
    static let previewCornerRadius = Key<CGFloat>("previewCornerRadius", default: 10, iCloud: true)
    static let previewBorderThickness = Key<CGFloat>("previewBorderThickness", default: 5, iCloud: true)

    // Behavior
    static let launchAtLogin = Key<Bool>("launchAtLogin", default: false, iCloud: true)
    static let hideMenuBarIcon = Key<Bool>("hideMenuBarIcon", default: false, iCloud: true)
    static let animationConfiguration = Key<AnimationConfiguration>("animationConfiguration", default: .fast, iCloud: true)
    static let windowSnapping = Key<Bool>("windowSnapping", default: false, iCloud: true)
    static let restoreWindowFrameOnDrag = Key<Bool>("restoreWindowFrameOnDrag", default: false, iCloud: true)
    static let enablePadding = Key<Bool>("enablePadding", default: false, iCloud: true)
    static let padding = Key<PaddingModel>("padding", default: .zero, iCloud: true)
    static let useScreenWithCursor = Key<Bool>("useScreenWithCursor", default: true, iCloud: true)
    static let moveCursorWithWindow = Key<Bool>("moveCursorWithWindow", default: false, iCloud: true)
    static let resizeWindowUnderCursor = Key<Bool>("resizeWindowUnderCursor", default: false, iCloud: true)
    static let focusWindowOnResize = Key<Bool>("focusWindowOnResize", default: true, iCloud: true)
    static let respectStageManager = Key<Bool>("respectStageManager", default: true, iCloud: true)
    static let stageStripSize = Key<CGFloat>("stageStripSize", default: 150, iCloud: true)

    // Keybindings
    static let triggerKey = Key<Set<CGKeyCode>>("trigger", default: [.kVK_Function], iCloud: true)
    static let triggerDelay = Key<Double>("triggerDelay", default: 0, iCloud: true)
    static let doubleClickToTrigger = Key<Bool>("doubleClickToTrigger", default: false, iCloud: true)
    static let middleClickTriggersLoop = Key<Bool>("middleClickTriggersLoop", default: false, iCloud: true)
    static let keybinds = Key<[WindowAction]>(
        "keybinds",
        default: [
            WindowAction(.maximize, keybind: [.kVK_Space]),
            WindowAction(.center, keybind: [.kVK_Return]),
            WindowAction(.init(localized: "Top Cycle"), [
                .init(.topHalf),
                .init(.topThird),
                .init(.topTwoThirds)
            ], [.kVK_UpArrow]),
            WindowAction(.init(localized: "Bottom Cycle"), [
                .init(.bottomHalf),
                .init(.bottomThird),
                .init(.bottomTwoThirds)
            ], [.kVK_DownArrow]),
            WindowAction(.init(localized: "Right Cycle"), [
                .init(.rightHalf),
                .init(.rightThird),
                .init(.rightTwoThirds)
            ], [.kVK_RightArrow]),
            WindowAction(.init(localized: "Left Cycle"), [
                .init(.leftHalf),
                .init(.leftThird),
                .init(.leftTwoThirds)
            ], [.kVK_LeftArrow]),
            WindowAction(.topLeftQuarter, keybind: [.kVK_UpArrow, .kVK_LeftArrow]),
            WindowAction(.topRightQuarter, keybind: [.kVK_UpArrow, .kVK_RightArrow]),
            WindowAction(.bottomRightQuarter, keybind: [.kVK_DownArrow, .kVK_RightArrow]),
            WindowAction(.bottomLeftQuarter, keybind: [.kVK_DownArrow, .kVK_LeftArrow])
        ],
        iCloud: true
    )

    // Advanced
    static let useSystemWindowManagerWhenAvailable = Key<Bool>("useSystemWindowManagerWhenAvailable", default: false, iCloud: true)
    static let animateWindowResizes = Key<Bool>("animateWindowResizes", default: false, iCloud: true)
    static let disableCursorInteraction = Key<Bool>("disableCursorInteraction", default: false, iCloud: true)
    static let ignoreFullscreen = Key<Bool>("ignoreFullscreen", default: false, iCloud: true)
    static let hideUntilDirectionIsChosen = Key<Bool>("hideUntilDirectionIsChosen", default: false, iCloud: true)
    static let hapticFeedback = Defaults.Key<Bool>("hapticFeedback", default: true, iCloud: true)

    // About
    static let includeDevelopmentVersions = Key<Bool>("includeDevelopmentVersions", default: false, iCloud: true)

    static let excludedApps = Key<[URL]>("excludedApps", default: [], iCloud: true)
    static let sizeIncrement = Key<CGFloat>("sizeIncrement", default: 20, iCloud: true)
}

// MARK: - Extra Advanced

extension Defaults.Keys {
    /// Adjust with `defaults write com.MrKai77.Loop paddingMinimumScreenSize -float x`
    /// Reset with `defaults delete com.MrKai77.Loop paddingMinimumScreenSize`
    static let paddingMinimumScreenSize = Key<CGFloat>("paddingMinimumScreenSize", default: 0, iCloud: true)

    // Radial Menu
    // It is not recommended to manually edit these entries yet, as it has not been tested.
    static let radialMenuTop = Key<WindowAction>(
        "radialMenuTop",
        default: .init([
            .init(.topHalf),
            .init(.topThird),
            .init(.topTwoThirds)
        ]),
        iCloud: true
    )
    static let radialMenuTopRight = Key<WindowAction>("radialMenuTopRight", default: .init(.topRightQuarter), iCloud: true)
    static let radialMenuRight = Key<WindowAction>(
        "radialMenuRight",
        default: .init([
            .init(.rightHalf),
            .init(.rightThird),
            .init(.rightTwoThirds)
        ]),
        iCloud: true
    )
    static let radialMenuBottomRight = Key<WindowAction>("radialMenuBottomRight", default: .init(.bottomRightQuarter), iCloud: true)
    static let radialMenuBottom = Key<WindowAction>(
        "radialMenuBottom",
        default: .init([
            .init(.bottomHalf),
            .init(.bottomThird),
            .init(.bottomTwoThirds)
        ]),
        iCloud: true
    )
    static let radialMenuBottomLeft = Key<WindowAction>("radialMenuBottomLeft", default: .init(.bottomLeftQuarter), iCloud: true)
    static let radialMenuLeft = Key<WindowAction>(
        "radialMenuLeft",
        default: .init([
            .init(.leftHalf),
            .init(.leftThird),
            .init(.leftTwoThirds)
        ]),
        iCloud: true
    )
    static let radialMenuTopLeft = Key<WindowAction>("radialMenuTopLeft", default: .init(.topLeftQuarter), iCloud: true)
    static let radialMenuCenter = Key<WindowAction>(
        "radialMenuCenter",
        default: .init([
            .init(.maximize),
            .init(.macOSCenter)
        ]),
        iCloud: true
    )
}
