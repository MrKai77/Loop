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
            String(localized: "px", comment: "Unit symbol: pixels")
        case .percentage:
            String(localized: "%", comment: "Unit symbol: percentage")
        }
    }

    var fractionLength: NumberFormatStyleConfiguration.Precision {
        switch self {
        case .pixels:
            .fractionLength(0)
        case .percentage:
            .fractionLength(2)
        }
    }

    func roundIfNeeded(_ value: Double) -> Double {
        switch self {
        case .pixels:
            value.rounded()
        case .percentage:
            (value * 100.0).rounded() / 100.0
        }
    }
}
