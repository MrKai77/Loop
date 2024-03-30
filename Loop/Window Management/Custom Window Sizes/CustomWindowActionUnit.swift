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

    var name: String {
        switch self {
        case .pixels:
            String(localized: "Pixels", comment: "An option when configuring a custom keybind's unit")
        case .percentage:
            String(localized: "Percentages", comment: "An option when configuring a custom keybind's unit")
        }
    }

    var icon: Image {
        switch self {
        case .pixels:
            Image(systemName: "rectangle.checkered")
        case .percentage:
            Image(systemName: "percent")
        }
    }

    var postscript: String {
        switch self {
        case .pixels: String(localized: "px", comment: "The short form of 'pixels'")
        case .percentage: String(localized: "%", comment: "The short form of 'percentage'")
        }
    }
}
