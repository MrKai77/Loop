//
//  StashDirection.swift
//  Loop
//
//  Created by Guillaume Clédat on 28/05/2025.
//

import Defaults
import Foundation

enum StashDirection: Codable, Defaults.Serializable {
    case left(StashRegion)
    case right(StashRegion)
}

/// Represents the vertical region along the screen’s edges where a window can be stashed.
///
/// This region determines how the window is positioned along the y-axis.
/// Some regions also modify the window's height, while its width remains unchanged.
///
/// - Note:
///   Currently, no regions modify the window’s width to keep the number of cases manageable.
///   By first applying one of the available `WindowDirection` options to set the window’s size,
///   and then stashing it in a `StashRegion`, the user can achieve a variety of stashed window sizes.
///
///   While it would be possible to add more `StashRegion` cases—such as ones modifying both height and width—
///   this would require creating a `WindowDirection` for each possible combination of `StashDirection` and `StashRegion`.
///
///   A solution would be to make stash work like WindowDirection.custom.
enum StashRegion: Codable, Defaults.Serializable {
    /// The top edge of the screen. The window retains its original size.
    case top
    /// The bottom edge of the screen. The window retains its original size.
    case bottom
    /// Vertically centered along the screen edge. The window retains its original size.
    case center
    /// The entire height of the screen edge. The window height is adjusted to fill the screen.
    case full
    /// The top half of the screen. The window height is adjusted to half the screen height.
    case topHalf
    /// The bottom half of the screen. The window height is adjusted to half the screen height.
    case bottomHalf
}

// MARK: - Helpers

extension StashDirection: Equatable {
    init?(direction: WindowDirection) {
        switch direction {
        case .stashTopLeft:
            self = .left(.top)
        case .stashBottomLeft:
            self = .left(.bottom)
        case .stashCenterLeft:
            self = .left(.center)
        case .stashFullLeft:
            self = .left(.full)
        case .stashTopHalfLeft:
            self = .left(.topHalf)
        case .stashBottomHalfLeft:
            self = .left(.bottomHalf)
        case .stashTopRight:
            self = .right(.top)
        case .stashBottomRight:
            self = .right(.bottom)
        case .stashCenterRight:
            self = .right(.center)
        case .stashFullRight:
            self = .right(.full)
        case .stashTopHalfRight:
            self = .right(.topHalf)
        case .stashBottomHalfRight:
            self = .right(.bottomHalf)
        default:
            return nil
        }
    }

    var region: StashRegion {
        switch self {
        case let .left(region), let .right(region):
            region
        }
    }

    static func == (lhs: StashDirection, rhs: StashDirection) -> Bool {
        switch (lhs, rhs) {
        case let (.left(lhs), .left(rhs)):
            lhs == rhs
        case let (.right(lhs), .right(rhs)):
            lhs == rhs
        default:
            false
        }
    }

    func isSameEdgeAs(_ other: StashDirection) -> Bool {
        switch (self, other) {
        case (.left, .left):
            true
        case (.right, .right):
            true
        default:
            false
        }
    }
}
