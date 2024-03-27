//
//  CustomWindowActionPositionMode.swift
//  Loop
//
//  Created by Kai Azim on 2024-03-22.
//

import SwiftUI

enum CustomWindowActionPositionMode: Int, Codable, CaseIterable, Identifiable {
    var id: Self { self }

    case generic = 0
    case coordinates = 1

    var label: Text {
        switch self {
        case .generic:
            Text("\(Image(systemName: "rectangle.dashed")) Generic")
        case .coordinates:
            Text("\(Image("custom.scope.rectangle")) Coordinates")
        }
    }
}
