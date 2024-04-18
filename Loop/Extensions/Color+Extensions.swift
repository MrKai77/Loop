//
//  Color+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-11.
//

import SwiftUI
import Defaults

extension Color {
    enum LoopAccentTone {
        case normal
        case darker
    }
    static func getLoopAccent(tone: LoopAccentTone) -> Color {
        switch tone {
        case .normal:
            if Defaults[.useSystemAccentColor] {
                return Color.accentColor
            }
            return Defaults[.customAccentColor]
        case .darker:
            if Defaults[.useSystemAccentColor] {
                return Color(nsColor: NSColor.controlAccentColor.blended(withFraction: 0.5, of: .black)!)
            }
            return Defaults[.gradientColor]
        }
    }
}
