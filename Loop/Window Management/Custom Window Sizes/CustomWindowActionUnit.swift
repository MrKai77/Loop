//
//  CustomWindowActionUnit.swift
//  Loop
//
//  Created by Kai Azim on 2024-01-01.
//

import SwiftUI

enum CustomWindowActionUnit: Int, Codable, CaseIterable, Identifiable {
    var id: Self { self }

    case pixels = 0
    case percentage = 1

    var label: Text {
        switch self {
        case .pixels:
            Text("\(Image(systemName: "rectangle.checkered")) Pixels")
        case .percentage:
            Text("\(Image(systemName: "percent")) Percentages")
        }
    }

    var suffix: String {
        switch self {
        case .pixels:
            "px"
        case .percentage:
            "%"
        }
    }
}
