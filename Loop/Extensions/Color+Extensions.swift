//
//  Color+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-11.
//

import Defaults
import SwiftUI

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

    static var systemGray: Color {
        Color(nsColor: NSColor.systemGray.blended(withFraction: 0.2, of: .black)!)
    }
}

// MARK: - Extension for wallpaper coloring

extension NSColor {
    // Converts NSColor to a hexadecimal string representation.
    var toHexString: String {
        let rgbColor = usingColorSpace(.deviceRGB) ?? NSColor.black
        let red = Int(round(rgbColor.redComponent * 0xFF))
        let green = Int(round(rgbColor.greenComponent * 0xFF))
        let blue = Int(round(rgbColor.blueComponent * 0xFF))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    // Determines if two colors are similar based on a threshold.
    func isSimilar(to color: NSColor, threshold: CGFloat = 0.1) -> Bool {
        let redDiff = abs(redComponent - color.redComponent)
        let greenDiff = abs(greenComponent - color.greenComponent)
        let blueDiff = abs(blueComponent - color.blueComponent)
        return (redDiff < threshold) && (greenDiff < threshold) && (blueDiff < threshold)
    }
}
