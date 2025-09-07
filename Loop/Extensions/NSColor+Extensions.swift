//
//  NSColor+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-11.
//

import AppKit

// MARK: - Extension for wallpaper coloring

extension NSColor {
    /// Converts NSColor to a hexadecimal string representation.
    /// If the color is not in the device RGB color space, it defaults to black.
    var toHexString: String {
        // Attempt to convert the color to the RGB color space.
        guard let rgbColor = usingColorSpace(.deviceRGB) else { return "#000000" }
        // Format the RGB components into a hexadecimal string.
        return String(format: "#%02X%02X%02X",
                      Int(rgbColor.redComponent * 0xFF),
                      Int(rgbColor.greenComponent * 0xFF),
                      Int(rgbColor.blueComponent * 0xFF))
    }

    /// Calculates the brightness of the color based on luminance.
    /// Brightness is calculated using the luminance formula, which considers the different contributions
    /// of the red, green, and blue components of the color. This property can be used to determine
    /// how light or dark a color is perceived to be.
    var brightness: CGFloat {
        // Ensure the color is in the sRGB color space for accurate luminance calculation.
        guard let rgbColor = usingColorSpace(.sRGB) else { return 0 }
        // Calculate brightness using the luminance formula.
        return 0.299 * rgbColor.redComponent + 0.587 * rgbColor.greenComponent + 0.114 * rgbColor.blueComponent
    }

    /// Returns the saturation component of the color.
    /// Higher values indicate more vibrant colors.
    var saturationComponent: CGFloat {
        guard let hsbColor = usingColorSpace(.deviceRGB) else { return 0 }
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        hsbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return saturation
    }

    /// Determines if two colors are similar based on a threshold.
    /// - Parameters:
    ///   - color: The color to compare with the receiver.
    ///   - threshold: The maximum allowed difference between color components.
    /// - Returns: A Boolean value indicating whether the two colors are similar.
    func isSimilar(to color: NSColor, threshold: CGFloat = 0.1) -> Bool {
        // Convert both colors to the RGB color space for comparison.
        guard let color1 = usingColorSpace(.deviceRGB),
              let color2 = color.usingColorSpace(.deviceRGB) else { return false }

        // Calculate difference in HSB space for better perceptual comparison
        var hue1: CGFloat = 0, sat1: CGFloat = 0, bri1: CGFloat = 0, alpha1: CGFloat = 0
        var hue2: CGFloat = 0, sat2: CGFloat = 0, bri2: CGFloat = 0, alpha2: CGFloat = 0

        color1.getHue(&hue1, saturation: &sat1, brightness: &bri1, alpha: &alpha1)
        color2.getHue(&hue2, saturation: &sat2, brightness: &bri2, alpha: &alpha2)

        // Hue is circular, so we need to account for colors like red (0) and purplish-red (0.95)
        let hueDiff = min(abs(hue1 - hue2), 1 - abs(hue1 - hue2))

        // For low saturation colors, hue matters less
        let hueThreshold = threshold * (1 + (1 - min(sat1, sat2)))

        return hueDiff < hueThreshold &&
            abs(sat1 - sat2) < threshold * 1.5 &&
            abs(bri1 - bri2) < threshold * 1.5
    }

    /// Quantizes the color to a limited set of values.
    /// This process reduces the color's precision, effectively snapping it to a grid
    /// in the color space defined by the quantization level. This simplification can
    /// be beneficial for analyzing colors in smaller images by reducing the color palette's complexity.
    /// - Returns: A quantized NSColor.
    func quantized(levels: Double = 512.0) -> NSColor {
        guard let sRGBColor = usingColorSpace(.sRGB) else { return self }
        let divisionFactor = levels - 1
        let red = round(sRGBColor.redComponent * divisionFactor) / divisionFactor
        let green = round(sRGBColor.greenComponent * divisionFactor) / divisionFactor
        let blue = round(sRGBColor.blueComponent * divisionFactor) / divisionFactor
        let alpha = round(sRGBColor.alphaComponent * divisionFactor) / divisionFactor
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}
