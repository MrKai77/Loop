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
    var gestureType: GestureType
    var action: GestureAction
    var activationZone: ActivationZone

    init(
        id: UUID = .init(),
        fingerCount: Int = 2,
        gestureType: GestureType = .radialMenu,
        action: GestureAction = .radialMenuActions,
        activationZone: ActivationZone = .titlebar
    ) {
        self.id = id
        self.fingerCount = fingerCount
        self.gestureType = gestureType
        self.action = action
        self.activationZone = activationZone
    }

    enum GestureType: Codable, Hashable, CaseIterable {
        /// Pan gesture that maps angle to radial menu directional slots.
        case radialMenu
        /// Directional pan gestures that trigger a single action.
        case panUp, panDown, panLeft, panRight
        /// Pinch gesture.
        case pinch

        var displayName: String {
            switch self {
            case .radialMenu: "Radial Menu"
            case .panUp: "Swipe Up"
            case .panDown: "Swipe Down"
            case .panLeft: "Swipe Left"
            case .panRight: "Swipe Right"
            case .pinch: "Pinch"
            }
        }

        var image: Image {
            switch self {
            case .radialMenu: Image(.loop)
            case .panUp: Image(systemName: "arrow.up")
            case .panDown: Image(systemName: "arrow.down")
            case .panLeft: Image(systemName: "arrow.left")
            case .panRight: Image(systemName: "arrow.right")
            case .pinch: Image(systemName: "arrow.down.left.and.arrow.up.right")
            }
        }

        var isPan: Bool {
            switch self {
            case .radialMenu, .panUp, .panDown, .panLeft, .panRight:
                true
            case .pinch:
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

    enum GestureAction: Codable, Hashable {
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

extension GestureBinding {
    /// Two bindings conflict when they have the same finger count and their gesture types overlap.
    /// Radial menu consumes both pan and pinch, so it conflicts with ANY other binding at the same finger count.
    func conflicts(with other: GestureBinding) -> Bool {
        guard id != other.id, fingerCount == other.fingerCount else {
            return false
        }

        // Radial menu uses both pan and pinch, so it conflicts with everything at the same finger count
        if gestureType == .radialMenu || other.gestureType == .radialMenu {
            return true
        }

        // Same gesture type always conflicts
        if gestureType == other.gestureType {
            return true
        }

        return false
    }

    /// Returns the IDs of all bindings that conflict with at least one other binding in the array.
    static func conflictingIDs(in bindings: [GestureBinding]) -> Set<UUID> {
        var result = Set<UUID>()
        for i in bindings.indices {
            for j in (i + 1) ..< bindings.count {
                if bindings[i].conflicts(with: bindings[j]) {
                    result.insert(bindings[i].id)
                    result.insert(bindings[j].id)
                }
            }
        }
        return result
    }
}

// MARK: - Defaults

extension GestureBinding {
    static let defaultBindings: [GestureBinding] = [
        GestureBinding(
            fingerCount: 2,
            gestureType: .radialMenu,
            action: .radialMenuActions,
            activationZone: .titlebar
        ),
        GestureBinding(
            fingerCount: 2,
            gestureType: .pinch,
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
