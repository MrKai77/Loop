//
//  CustomWindowActionSizeMode.swift
//  Loop
//
//  Created by Kai Azim on 2024-03-22.
//

import SwiftUI

enum CustomWindowActionSizeMode: Int, Codable, CaseIterable, Identifiable {
    var id: Self { self }

    case custom = 0
    case preserveSize = 1
    case initialSize = 2

    var name: LocalizedStringKey {
        switch self {
        case .custom:
            "Custom"
        case .preserveSize:
            "Preserve Size"
        case .initialSize:
            "Initial Size"
        }
    }

    var image: Image {
        switch self {
        case .custom:
            Image(._18PxRulerPen)
        case .preserveSize:
            Image(._18PxTableLock)
        case .initialSize:
            Image(._18PxReturnKey)
        }
    }
}
