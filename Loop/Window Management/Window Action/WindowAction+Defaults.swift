//
//  WindowAction+Defaults.swift
//  Loop
//
//  Created by Kai Azim on 2025-11-11.
//

import Defaults
import Foundation

// MARK: Keybinds

extension WindowAction {
    static let defaultKeybinds: [WindowAction] = [
        WindowAction(.maximize, keybind: [.kVK_Space]),
        WindowAction(.center, keybind: [.kVK_Return]),
        WindowAction(
            .init(localized: "Top Cycle"),
            cycle: [.init(.topHalf), .init(.topThird), .init(.topTwoThirds)],
            keybind: [.kVK_UpArrow]
        ),
        WindowAction(
            .init(localized: "Bottom Cycle"),
            cycle: [.init(.bottomHalf), .init(.bottomThird), .init(.bottomTwoThirds)],
            keybind: [.kVK_DownArrow]
        ),
        WindowAction(
            .init(localized: "Right Cycle"),
            cycle: [.init(.rightHalf), .init(.rightThird), .init(.rightTwoThirds)],
            keybind: [.kVK_RightArrow]
        ),
        WindowAction(
            .init(localized: "Left Cycle"),
            cycle: [.init(.leftHalf), .init(.leftThird), .init(.leftTwoThirds)],
            keybind: [.kVK_LeftArrow]
        ),
        WindowAction(.topLeftQuarter, keybind: [.kVK_UpArrow, .kVK_LeftArrow]),
        WindowAction(.topRightQuarter, keybind: [.kVK_UpArrow, .kVK_RightArrow]),
        WindowAction(.bottomRightQuarter, keybind: [.kVK_DownArrow, .kVK_RightArrow]),
        WindowAction(.bottomLeftQuarter, keybind: [.kVK_DownArrow, .kVK_LeftArrow])
    ]
}
