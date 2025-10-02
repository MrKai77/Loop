//
//  Defaults+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//
// NOTE: While iCloud is enabled, its service is currently disabled to make GitHub actions work.

import Defaults
import SwiftUI

// MARK: - UI-configurable Settings

extension Defaults.Keys {
    // Icon
    static let currentIcon = Key<String>("currentIcon", default: "AppIcon-Classic", iCloud: true)
    static let timesLooped = Key<Int>("timesLooped", default: 0, iCloud: true)
    static let showDockIcon = Key<Bool>("showDockIcon", default: false, iCloud: true)
    static let notificationWhenIconUnlocked = Key<Bool>("notificationWhenIconUnlocked", default: true, iCloud: true)

    // Accent Color
    static let accentColorMode: Key<AccentColorOption> = Key("accentColorMode", default: .system, iCloud: true)
    static let customAccentColor = Key<Color>("customAccentColor", default: Color(.white), iCloud: true)
    static let useGradient = Key<Bool>("useGradient", default: true, iCloud: true)
    static let gradientColor = Key<Color>("gradientColor", default: Color(.black), iCloud: true)

    // Radial Menu
    static let radialMenuVisibility = Key<Bool>("radialMenuVisibility", default: true, iCloud: true)
    static let radialMenuCornerRadius = Key<CGFloat>("radialMenuCornerRadius", default: 50, iCloud: true)
    static let radialMenuThickness = Key<CGFloat>("radialMenuThickness", default: 22, iCloud: true)
    /// Lock radial menu to the center of the screen
    /// Adjust with `defaults write com.MrKai77.Loop lockRadialMenuToCenter -bool true`
    /// Reset with `defaults delete com.MrKai77.Loop lockRadialMenuToCenter`
    static let lockRadialMenuToCenter = Key<Bool>("lockRadialMenuToCenter", default: false, iCloud: true)

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
    static let suppressMissionControlOnTopDrag = Key<Bool>("suppressMissionControlOnTopDrag", default: true, iCloud: true)
    static let restoreWindowFrameOnDrag = Key<Bool>("restoreWindowFrameOnDrag", default: false, iCloud: true)
    static let enablePadding = Key<Bool>("enablePadding", default: false, iCloud: true)
    static let padding = Key<PaddingModel>("padding", default: .zero, iCloud: true)
    static let useScreenWithCursor = Key<Bool>("useScreenWithCursor", default: true, iCloud: true)
    static let moveCursorWithWindow = Key<Bool>("moveCursorWithWindow", default: false, iCloud: true)
    static let resizeWindowUnderCursor = Key<Bool>("resizeWindowUnderCursor", default: false, iCloud: true)
    static let focusWindowOnResize = Key<Bool>("focusWindowOnResize", default: true, iCloud: true)
    static let respectStageManager = Key<Bool>("respectStageManager", default: true, iCloud: true)
    static let stageStripSize = Key<CGFloat>("stageStripSize", default: 150, iCloud: true)
    static let animateStashedWindows = Key<Bool>("animateStashedWindows", default: true, iCloud: true)
    static let stashedWindowVisiblePadding = Key<CGFloat>("stashedWindowVisiblePadding", default: 20, iCloud: true)
    static let shiftFocusWhenStashed = Key<Bool>("shiftFocusWhenStashed", default: true, iCloud: true)
    static let cycleModeRestartEnabled = Key<Bool>("cycleModeRestartEnabled", default: false, iCloud: true)

    // Keybinds
    static let triggerKey = Key<Set<CGKeyCode>>("trigger", default: [.kVK_Function], iCloud: true)
    static let triggerDelay = Key<Double>("triggerDelay", default: 0, iCloud: true)
    static let doubleClickToTrigger = Key<Bool>("doubleClickToTrigger", default: false, iCloud: true)
    static let middleClickTriggersLoop = Key<Bool>("middleClickTriggersLoop", default: false, iCloud: true)
    static let enableTriggerDelayOnMiddleClick = Key<Bool>("enableTriggerDelayOnMiddleClick", default: false, iCloud: true)
    static let cycleBackwardsOnShiftPressed = Key<Bool>("cycleBackwardsOnShiftPressed", default: true, iCloud: true)
    static let keybinds = Key<[WindowAction]>(
        "keybinds",
        default: [
            WindowAction(.maximize, keybind: [.kVK_Space]),
            WindowAction(.center, keybind: [.kVK_Return]),
            WindowAction(
                .init(localized: "Top Cycle"),
                cycle: [
                    .init(.topHalf),
                    .init(.topThird),
                    .init(.topTwoThirds)
                ],
                keybind: [.kVK_UpArrow]
            ),
            WindowAction(
                .init(localized: "Bottom Cycle"),
                cycle: [
                    .init(.bottomHalf),
                    .init(.bottomThird),
                    .init(.bottomTwoThirds)
                ],
                keybind: [.kVK_DownArrow]
            ),
            WindowAction(
                .init(localized: "Right Cycle"),
                cycle: [
                    .init(.rightHalf),
                    .init(.rightThird),
                    .init(.rightTwoThirds)
                ],
                keybind: [.kVK_RightArrow]
            ),
            WindowAction(
                .init(localized: "Left Cycle"),
                cycle: [
                    .init(.leftHalf),
                    .init(.leftThird),
                    .init(.leftTwoThirds)
                ],
                keybind: [.kVK_LeftArrow]
            ),
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
    /// Disable automatic updates with `defaults write com.MrKai77.Loop updatesEnabled -bool false`
    /// Reset with `defaults delete com.MrKai77.Loop updatesEnabled`
    static let updatesEnabled = Key<Bool>("updatesEnabled", default: true, iCloud: true)

    static let excludedApps = Key<[URL]>("excludedApps", default: [], iCloud: true)
    static let sizeIncrement = Key<CGFloat>("sizeIncrement", default: 20, iCloud: true)
}

// MARK: - Hidden Settings

extension Defaults.Keys {
    /// Minimum screen size, defined in inches on the diagonal, for which padding will be applied on windows.
    /// Adjust with `defaults write com.MrKai77.Loop paddingMinimumScreenSize -float x`
    /// Reset with `defaults delete com.MrKai77.Loop paddingMinimumScreenSize`
    static let paddingMinimumScreenSize = Key<CGFloat>("paddingMinimumScreenSize", default: 0, iCloud: true)

    /// Snap threshold for window snapping, defined in points.
    /// Adjust with `defaults write com.MrKai77.Loop snapThreshold -float x`
    /// Reset with `defaults delete com.MrKai77.Loop snapThreshold`
    static let snapThreshold = Key<CGFloat>("snapThreshold", default: 2, iCloud: true)

    /// Whether to ignore low power mode for certain features, such as window animations.
    /// Adjust with `defaults write com.MrKai77.Loop ignoreLowPowerMode -bool x`
    /// Reset with `defaults delete com.MrKai77.Loop ignoreLowPowerMode`
    static let ignoreLowPowerMode = Key<Bool>("ignoreLowPowerMode", default: false, iCloud: true)

    /// Adjust with `defaults write com.MrKai77.Loop previewStartingPosition [option]`
    /// Reset with `defaults delete com.MrKai77.Loop previewStartingPosition`
    ///
    /// Available options:
    /// - `screenCenter`: Center of the screen (default behavior)
    /// - `radialMenu`: Center of radial menu
    /// - `actionCenter`: Center of the selected action (e.g. for left half, it will grow from the center of that left half)
    static let previewStartingPosition = Key<PreviewStartingPosition>("previewStartingPosition", default: .screenCenter, iCloud: true)

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

    // Migrator
    static let lastMigratorURL = Key<URL?>("lastMigratorURL", default: nil)

    // StashManager
    static let stashManagerRevealedWindows = Key<Set<CGWindowID>>("stashManagerRevealed", default: Set<CGWindowID>())
    static let stashManagerStashedWindows = Key<[CGWindowID: WindowAction]>("stashManagerStashed", default: [:])

    // AccentColorController
    static let lastUsedAccentColor1 = Key<Color>("lastUsedAccentColor1", default: .black)
    static let lastUsedAccentColor2 = Key<Color>("lastUsedAccentColor2", default: .black)

    @available(*, deprecated, renamed: "accentColorMode", message: "Use accentColorMode.system")
    static let useSystemAccentColor = Key<Bool>("useSystemAccentColor", default: true, iCloud: true)

    @available(*, deprecated, renamed: "accentColorMode", message: "Use accentColorMode.wallpaper")
    static let processWallpaper = Key<Bool>("processWallpaper", default: false, iCloud: true)

    // DataPatcher
    static let patchesApplied = Key<DataPatcher.Patch>("patchesApplied", default: [], iCloud: true)
}
