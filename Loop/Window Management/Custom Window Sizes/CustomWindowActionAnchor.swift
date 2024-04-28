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

    var image: Image {
        switch self {
        case .topLeft:
            Image(systemName: "rectangle.inset.topleft.filled")
        case .top:
            Image(systemName: "rectangle.tophalf.inset.filled")
        case .topRight:
            Image(systemName: "rectangle.inset.topright.filled")
        case .right:
            Image(systemName: "rectangle.righthalf.inset.filled")
        case .bottomRight:
            Image(systemName: "rectangle.inset.bottomright.filled")
        case .bottom:
            Image(systemName: "rectangle.bottomhalf.inset.filled")
        case .bottomLeft:
            Image(systemName: "rectangle.inset.bottomleft.filled")
        case .left:
            Image(systemName: "rectangle.lefthalf.inset.filled")
        case .center, .macOSCenter:
            Image("custom.rectangle.center.inset.inset.filled")
        }
    }
}
