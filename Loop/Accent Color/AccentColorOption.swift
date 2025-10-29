//
//  AccentColorOption.swift
//  Loop
//
//  Created by Kai Azim on 2025-09-07.
//

import Defaults
import SwiftUI

enum AccentColorOption: Int, Codable, Defaults.Serializable, CaseIterable {
    case system
    case wallpaper
    case custom

    var image: Image {
        switch self {
        case .system: Image(systemName: "apple.logo")
        case .wallpaper: Image(.imageDepth)
        case .custom: Image(.colorPalette)
        }
    }

    var text: String {
        switch self {
        case .system: String(localized: "System", comment: "Accent color option")
        case .wallpaper: String(localized: "Wallpaper", comment: "Accent color option")
        case .custom: String(localized: "Custom", comment: "Accent color option")
        }
    }
}
