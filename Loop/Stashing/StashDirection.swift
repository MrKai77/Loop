//
//  StashDirection.swift
//  Loop
//
//  Created by Guillaume Clédat on 28/05/2025.
//

import Defaults
import Foundation

enum StashEdge: String, CustomDebugStringConvertible {
    case left
    case right
    case bottom

    var debugDescription: String {
        rawValue
    }

    var isHorizontal: Bool {
        self == .left || self == .right
    }
}

// MARK: - Helpers

extension WindowAction {
    var stashEdge: StashEdge? {
        switch direction {
        case .stash where anchor == .left:
            .left
        case .stash where anchor == .right:
            .right
        case .stash where anchor == .bottom:
            .bottom
        case .stash where anchor == .topLeft:
            .left
        case .stash where anchor == .topRight:
            .right
        case .stash where anchor == .bottomLeft:
            .left
        case .stash where anchor == .bottomRight:
            .right
        default:
            nil
        }
    }
}
