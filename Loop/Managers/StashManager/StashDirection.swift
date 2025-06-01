//
//  StashDirection.swift
//  Loop
//
//  Created by Guillaume Clédat on 28/05/2025.
//

import Defaults
import Foundation

enum StashEdge {
    case left
    case right
}

// MARK: - Helpers

extension WindowAction {
    private var leftEdgeStashDirections: [WindowDirection] {
        [.stashLeftHalf, .stashTopLeftQuarter, .stashBottomLeftQuarter, .stashLeftThird, .stashLeftTwoThirds]
    }

    private var rightEdgeStashDirections: [WindowDirection] {
        [.stashRightHalf, .stashTopRightQuarter, .stashBottomRightQuarter, .stashRightThird, .stashRightTwoThirds]
    }

    var stashEdge: StashEdge? {
        switch direction {
        case let direction where leftEdgeStashDirections.contains(direction):
            .left
        case let direction where rightEdgeStashDirections.contains(direction):
            .right
        case .customStash where [.left, .topLeft, .bottomLeft].contains(anchor):
            .left
        case .customStash where [.right, .topRight, .bottomRight].contains(anchor):
            .right
        default:
            nil
        }
    }
}
