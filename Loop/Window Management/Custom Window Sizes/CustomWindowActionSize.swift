//
//  CustomWindowActionSize.swift
//  Loop
//
//  Created by Kai Azim on 2024-03-22.
//

import SwiftUI

enum CustomWindowActionSize: Int, Codable, CaseIterable, Identifiable {
    var id: Self { self }

    case custom = 0
    case preserveSize = 1
    case initialSize = 2

    var label: Text {
        switch self {
        case .custom:
            Text("\(Image(systemName: "rectangle.dashed")) Custom")
        case .preserveSize:
            Text("\(Image(systemName: "lock.rectangle")) Preserve Size")
        case .initialSize:
            Text("\( Image("custom.backward.end.alt.fill.2.rectangle")) Initial Size")
        }
    }
}
