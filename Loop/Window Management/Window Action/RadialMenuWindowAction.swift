//
//  RadialMenuWindowAction.swift
//  Loop
//
//  Created by Kai Azim on 2025-11-11.
//

import Defaults
import Foundation

enum RadialMenuWindowAction: Identifiable, Codable, Hashable, Defaults.Serializable {
    case custom(WindowAction)
    case keybindReference(UUID)

    var id: UUID {
        switch self {
        case let .custom(windowAction):
            windowAction.id
        case let .keybindReference(id):
            id
        }
    }

    var resolvedAction: WindowAction? {
        switch self {
        case let .custom(windowAction):
            windowAction
        case let .keybindReference(id):
            if let action = Defaults[.keybinds].first(where: { $0.id == id }) {
                action
            } else {
                nil
            }
        }
    }

    var isKeybindReference: Bool {
        switch self {
        case .custom:
            false
        case .keybindReference:
            true
        }
    }

    var keybindIndex: Int? {
        switch self {
        case .custom:
            nil
        case let .keybindReference(id):
            Defaults[.keybinds].firstIndex { $0.id == id }
        }
    }

    static let defaultRadialMenuActions: [RadialMenuWindowAction] = [
        .custom(
            WindowAction(
                .init(localized: "Top Cycle"),
                cycle: [.init(.topHalf), .init(.topThird), .init(.topTwoThirds)]
            )
        ),
        .custom(WindowAction(.topRightQuarter)),
        .custom(
            WindowAction(
                .init(localized: "Right Cycle"),
                cycle: [.init(.rightHalf), .init(.rightThird), .init(.rightTwoThirds)]
            )
        ),
        .custom(WindowAction(.bottomRightQuarter)),
        .custom(
            WindowAction(
                .init(localized: "Bottom Cycle"),
                cycle: [.init(.bottomHalf), .init(.bottomThird), .init(.bottomTwoThirds)]
            )
        ),
        .custom(WindowAction(.bottomLeftQuarter)),
        .custom(
            WindowAction(
                .init(localized: "Left Cycle"),
                cycle: [.init(.leftHalf), .init(.leftThird), .init(.leftTwoThirds)]
            )
        ),
        .custom(WindowAction(.topLeftQuarter)),
        .custom(
            WindowAction(
                "\(WindowDirection.maximize.name) + \(WindowDirection.macOSCenter.name)",
                cycle: [
                    .init(.maximize),
                    .init(.macOSCenter)
                ]
            )
        )
    ]
}
