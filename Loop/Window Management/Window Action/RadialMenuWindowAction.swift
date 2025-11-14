//
//  RadialMenuWindowAction.swift
//  Loop
//
//  Created by Kai Azim on 2025-11-11.
//

import Defaults
import Foundation

enum RadialMenuWindowAction: Codable, Defaults.Serializable {
    case custom(WindowAction)
    case keybindReference(UUID)

    static let defaultRadialMenuActions: [RadialMenuWindowAction] = [
        .custom(.init([.init(.maximize), .init(.macOSCenter)])),
        .custom(.init([.init(.rightHalf), .init(.rightThird), .init(.rightTwoThirds)])),
        .custom(.init(.bottomRightQuarter)),
        .custom(.init([.init(.bottomHalf), .init(.bottomThird), .init(.bottomTwoThirds)])),
        .custom(.init(.bottomLeftQuarter)),
        .custom(.init([.init(.leftHalf), .init(.leftThird), .init(.leftTwoThirds)])),
        .custom(.init(.topLeftQuarter)),
        .custom(.init([.init(.topHalf), .init(.topThird), .init(.topTwoThirds)])),
        .custom(.init(.topRightQuarter))
    ]
}
