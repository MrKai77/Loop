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

    var label: Text {
        switch self {
        case .topLeft: Text("\(Image(systemName: "arrow.up.left")) Top Left")
        case .top: Text("\(Image(systemName: "arrow.up")) Top")
        case .topRight: Text("\(Image(systemName: "arrow.up.right")) Top Right")
        case .right: Text("\(Image(systemName: "arrow.right")) Right")
        case .bottomRight: Text("\(Image(systemName: "arrow.down.right")) Bottom Right")
        case .bottom: Text("\(Image(systemName: "arrow.down")) Bottom")
        case .bottomLeft: Text("\(Image(systemName: "arrow.down.left")) Bottom Left")
        case .left: Text("\(Image(systemName: "arrow.left")) Left")
        case .center: Text("\(Image(systemName: "scope")) Center")
        case .macOSCenter: Text("\(Image(systemName: "scope")) MacOS Center")
        }
    }
}
