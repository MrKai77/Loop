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

    var name: String {
        switch self {
        case .generic:
            String(localized: "Generic", comment: "An option when configuring a custom keybind's position mode")
        case .coordinates:
            String(localized: "Coordinates", comment: "An option when configuring a custom keybind's position mode")
        }
    }

    var icon: Image {
        switch self {
        case .generic:
            Image(systemName: "rectangle.dashed")
        case .coordinates:
            Image("custom.scope.rectangle")
        }
    }
}
