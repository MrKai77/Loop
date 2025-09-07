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

    var suffix: String {
        switch self {
        case .pixels:
            .init(localized: "Measurement unit: pixels", defaultValue: "px")
        case .percentage:
            .init(localized: "Measurement unit: percentage", defaultValue: "%")
        }
    }
}
