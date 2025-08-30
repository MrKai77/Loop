//
//  StashDirection.swift
//  Loop
//
//  Created by Guillaume Clédat on 2025-05-28.

import Defaults
import Foundation

enum StashEdge {
    case left
    case right
}

// MARK: - Helpers

extension WindowAction {
    var stashEdge: StashEdge? {
        switch direction {
        case .stash where [.left, .topLeft, .bottomLeft].contains(anchor):
            .left
        case .stash where [.right, .topRight, .bottomRight].contains(anchor):
            .right
        default:
            nil
        }
    }
}
