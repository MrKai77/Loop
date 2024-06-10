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

    var iconAction: WindowAction {
        switch self {
        case .topLeft:      .init(.topLeftQuarter)
        case .top:          .init(.topHalf)
        case .topRight:     .init(.topRightQuarter)
        case .right:        .init(.rightHalf)
        case .bottomRight:  .init(.bottomRightQuarter)
        case .bottom:       .init(.bottomHalf)
        case .bottomLeft:   .init(.bottomLeftQuarter)
        case .left:         .init(.leftHalf)
        case .center:       .init(.center)
        case .macOSCenter:  .init(.macOSCenter)
        }
    }

//    var image: IconView {
//        switch self {
//        case .topLeft:
//            IconView(action: .constant(.init(.topLeftQuarter)))
//        case .top:
//            IconView(action: .constant(.init(.topHalf)))
//        case .topRight:
//            IconView(action: .constant(.init(.topRightQuarter)))
//        case .right:
//            IconView(action: .constant(.init(.rightHalf)))
//        case .bottomRight:
//            IconView(action: .constant(.init(.bottomRightQuarter)))
//        case .bottom:
////            Image(systemName: "rectangle.bottomhalf.inset.filled")
//        case .bottomLeft:
////            Image(systemName: "rectangle.inset.bottomleft.filled")
//        case .left:
////            Image(systemName: "rectangle.lefthalf.inset.filled")
//        case .center:
////            Image("custom.rectangle.center.inset.inset.filled")
//        case ..macOSCenter:
//
//        }
//    }
}
