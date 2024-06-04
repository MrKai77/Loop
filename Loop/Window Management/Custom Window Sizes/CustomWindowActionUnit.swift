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

    var suffix: LocalizedStringKey {
        switch self {
        case .pixels:
            "px"
        case .percentage:
            "%"
        }
    }
}
