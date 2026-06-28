//
//  GestureBinding.swift
//  Loop
//
//  Created by Kai Azim on 2026-04-16.
//

import Defaults
import SwiftUI

struct GestureBinding: Identifiable, Codable, Hashable, Defaults.Serializable {
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
            case .radialMenu: String(localized: "Radial Menu", comment: "Gesture kind: opens the radial menu via swipe/pinch/spread")
            case .panUp: String(localized: "Swipe Up", comment: "Gesture kind: directional swipe")
            case .panDown: String(localized: "Swipe Down", comment: "Gesture kind: directional swipe")
            case .panLeft: String(localized: "Swipe Left", comment: "Gesture kind: directional swipe")
            case .panRight: String(localized: "Swipe Right", comment: "Gesture kind: directional swipe")
            case .pinch: String(localized: "Pinch", comment: "Gesture kind: fingers move together")
            case .spread: String(localized: "Spread", comment: "Gesture kind: fingers move apart")
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
            case .titlebar: String(localized: "Titlebar Only", comment: "Gesture activation zone restricted to a window's titlebar")
            case .anywhere: String(localized: "Anywhere", comment: "Gesture activation zone covers the entire window")
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

// MARK: - Disabled state

extension GestureBinding {
    /// True when this gesture's action resolves to `noAction`. Disabled gestures
    /// are skipped at runtime and rendered greyed-out in settings.
    var isDisabled: Bool {
        switch action {
        case .radialMenuActions:
            false
        case let .singleAction(actionType):
            (actionType.resolvedAction?.direction ?? .noAction) == .noAction
        }
    }
}

// MARK: - Conflict Detection

extension GestureBinding {
    /// Returns the IDs of enabled gestures that conflict with at least one other enabled gesture.
    static func conflictingEnabledIDs(in gestures: [GestureBinding]) -> Set<UUID> {
        conflictingIDs(in: gestures.filter { !$0.isDisabled })
    }

    /// Two gestures conflict when they have the same finger count and their kinds overlap.
    /// Radial menu consumes both pan and pinch, so it conflicts with ANY other gesture at the same finger count.
    func conflicts(with other: GestureBinding) -> Bool {
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
    static func conflictingIDs(in gestures: [GestureBinding]) -> Set<UUID> {
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

extension GestureBinding {
    static let defaults: [GestureBinding] = [
        GestureBinding(
            fingerCount: 2,
            kind: .radialMenu,
            action: .radialMenuActions,
            activationZone: .titlebar
        )
    ]
}
