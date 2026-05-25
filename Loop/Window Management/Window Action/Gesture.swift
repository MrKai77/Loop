//
//  Gesture.swift
//  Loop
//
//  Created by Kai Azim on 2026-04-16.
//

import Defaults
import SwiftUI

struct Gesture: Identifiable, Codable, Hashable, Defaults.Serializable {
    let id: UUID
    var fingerCount: Int
    var kind: Kind
    var action: Action
    var activationZone: ActivationZone

    init(
        id: UUID = .init(),
        fingerCount: Int = 2,
        kind: Kind = .radialMenu,
        action: Action = .radialMenuActions,
        activationZone: ActivationZone = .titlebar
    ) {
        self.id = id
        self.fingerCount = fingerCount
        self.kind = kind
        self.action = action
        self.activationZone = activationZone
    }

    enum Kind: Codable, Hashable, CaseIterable {
        /// Pan gesture that maps angle to radial menu directional slots.
        case radialMenu
        /// Directional pan gestures that trigger a single action.
        case panUp, panDown, panLeft, panRight
        /// Pinch gesture (fingers together, scale < 1).
        case pinch
        /// Spread gesture (fingers apart, scale > 1).
        case spread

        var displayName: String {
            switch self {
            case .radialMenu: "Radial Menu"
            case .panUp: "Swipe Up"
            case .panDown: "Swipe Down"
            case .panLeft: "Swipe Left"
            case .panRight: "Swipe Right"
            case .pinch: "Pinch"
            case .spread: "Spread"
            }
        }

        var image: Image {
            switch self {
            case .radialMenu: Image(.loop)
            case .panUp: Image(systemName: "arrow.up")
            case .panDown: Image(systemName: "arrow.down")
            case .panLeft: Image(systemName: "arrow.left")
            case .panRight: Image(systemName: "arrow.right")
            case .pinch: Image(systemName: "arrow.up.right.and.arrow.down.left")
            case .spread: Image(systemName: "arrow.down.left.and.arrow.up.right")
            }
        }

        var isPan: Bool {
            switch self {
            case .radialMenu, .panUp, .panDown, .panLeft, .panRight:
                true
            case .pinch, .spread:
                false
            }
        }

        var isDirectionalPan: Bool {
            switch self {
            case .panUp, .panDown, .panLeft, .panRight:
                true
            default:
                false
            }
        }
    }

    enum Action: Codable, Hashable {
        /// Uses `RadialMenuAction.userConfiguredActions` for radial menu pan mode.
        case radialMenuActions
        /// A single action, either custom or referencing a keybind.
        case singleAction(RadialMenuAction.ActionType)
    }

    enum ActivationZone: String, Codable, Hashable, CaseIterable {
        case titlebar
        case anywhere

        var displayName: String {
            switch self {
            case .titlebar: "Titlebar"

            case .anywhere: "Anywhere"
            }
        }

        var systemImage: String {
            switch self {
            case .titlebar: "menubar.rectangle"
            case .anywhere: "rectangle.dashed"
            }
        }
    }
}

// MARK: - Conflict Detection

extension Gesture {
    /// Two gestures conflict when they have the same finger count and their kinds overlap.
    /// Radial menu consumes both pan and pinch, so it conflicts with ANY other gesture at the same finger count.
    func conflicts(with other: Gesture) -> Bool {
        guard id != other.id, fingerCount == other.fingerCount else {
            return false
        }

        // Radial menu uses both pan and pinch, so it conflicts with everything at the same finger count
        if kind == .radialMenu || other.kind == .radialMenu {
            return true
        }

        // Same kind always conflicts
        if kind == other.kind {
            return true
        }

        return false
    }

    /// Returns the IDs of all gestures that conflict with at least one other gesture in the array.
    static func conflictingIDs(in gestures: [Gesture]) -> Set<UUID> {
        var result = Set<UUID>()
        for i in gestures.indices {
            for j in (i + 1) ..< gestures.count {
                if gestures[i].conflicts(with: gestures[j]) {
                    result.insert(gestures[i].id)
                    result.insert(gestures[j].id)
                }
            }
        }
        return result
    }
}

// MARK: - Defaults

extension Gesture {
    static let defaults: [Gesture] = [
        Gesture(
            fingerCount: 2,
            kind: .radialMenu,
            action: .radialMenuActions,
            activationZone: .titlebar
        ),
        Gesture(
            fingerCount: 2,
            kind: .pinch,
            action: .singleAction(.custom(
                WindowAction(
                    "\(WindowDirection.maximize.name) + \(WindowDirection.macOSCenter.name)",
                    cycle: [
                        .init(.maximize),
                        .init(.macOSCenter)
                    ]
                )
            )),
            activationZone: .titlebar
        )
    ]
}
