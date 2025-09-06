//
//  CustomWindowActionAnchor.swift
//  Loop
//
//  Created by Kai Azim on 2024-01-01.
//

import SwiftUI

enum CustomWindowActionAnchor: Int, Codable, CaseIterable, Identifiable {
    var id: Self { self }

    case topLeft = 0
    case top = 1
    case topRight = 2
    case right = 3
    case bottomRight = 4
    case bottom = 5
    case bottomLeft = 6
    case left = 7
    case center = 8
    case macOSCenter = 9
}

extension CustomWindowActionAnchor {
    private static var iconActionCache: [CustomWindowActionAnchor: WindowAction] = [:]

    var iconAction: WindowAction {
        // Prevents re-initializing the same action multiple times
        if let cachedAction = CustomWindowActionAnchor.iconActionCache[self] {
            return cachedAction
        }

        let newAction: WindowAction = switch self {
        case .topLeft: .init(.topLeftQuarter)
        case .top: .init(.topHalf)
        case .topRight: .init(.topRightQuarter)
        case .right: .init(.rightHalf)
        case .bottomRight: .init(.bottomRightQuarter)
        case .bottom: .init(.bottomHalf)
        case .bottomLeft: .init(.bottomLeftQuarter)
        case .left: .init(.leftHalf)
        case .center: .init(.center)
        case .macOSCenter: .init(.macOSCenter)
        }

        CustomWindowActionAnchor.iconActionCache[self] = newAction
        return newAction
    }
}
