//
//  WallpaperProcessor.swift
//  Loop
//
//  Created by Kami on 27/06/2024.
//

import AppKit
import Defaults
import OSLog
import SwiftUI

// MARK: - Wallpaper processor errors

/// Represents errors that can occur during wallpaper processing.
public enum WallpaperProcessorError: LocalizedError {
    case screenshotFailed
    case dominantColorsCalculationFailed
    case noWallpaperWindowsFound
    case wallpaperWindowCaptureFailed
    case imageResizeFailed
    case bitmapCreationFailed

    var errorDescription: String {
        switch self {
        case .screenshotFailed:
            "Screenshot failed."
        case .dominantColorsCalculationFailed:
            "Failed to calculate dominant colors."
        case .noWallpaperWindowsFound:
            "No wallpaper windows found"
        case .wallpaperWindowCaptureFailed:
            "Failed to capture wallpaper window"
        case .imageResizeFailed:
            "Could not resize image."
        case .bitmapCreationFailed:
            "Failed to create bitmap image"
        }
    }
}

// MARK: - Wallpaper public function

/// Processes desktop wallpapers to extract colors for theming Loop.
/// This class provides methods to capture the current desktop wallpaper and extract
/// vibrant, visually appealing colors that can be used as accent colors in the UI.
final class WallpaperProcessor {
    private var lastProcessedDate: Date = .distantPast
    private var lastResult: (primary: Color, secondary: Color) = (.black, .black)
    private let logger = Logger(category: "WallpaperProcessor")

    /// Fetches the latest wallpaper colors, respecting a throttle period.
    /// This helps prevent excessive processing if called frequently, when the wallpaper is most likely unchanged.
    /// - Parameter ignoreThrottle: If true, the method will ignore the throttle and fetch colors immediately. This is useful when called from settings or manual triggers.
    func fetchLatest(ignoreThrottle: Bool = false) async -> (primary: Color, secondary: Color) {
        // Only proceed if the caller has chosen to ignore the throttle, or over 5 seconds have passed since the last refresh
        guard ignoreThrottle || lastProcessedDate.distance(to: .now) > 5.0 else {
            return lastResult
        }
        lastProcessedDate = .now

        // If we succeed in obtaining new colors, then return them
        if let newColors = await fetchLatestWallpaperColors() {
            lastResult = newColors
            return newColors
        }

        // If we didn't succeed, simply return the last set of valid colors
        return lastResult
    }

    /// Fetches the latest wallpaper colors and updates the app's theme settings.
    ///
    /// This method:
    /// 1. Captures the current wallpaper image
    /// 2. Processes it to extract dominant colors
    /// 3. Updates the app's accent color settings with the extracted colors
    ///
    /// The first (most vibrant) color is used as the primary accent color, while
    /// the second color is used as a gradient/secondary color. This provides
    /// a cohesive theme that matches the user's desktop environment.
    ///
    /// Note that you shouldn't call this method directly, but rather, call ``AccentColorController.refresh``.
    private func fetchLatestWallpaperColors() async -> (primary: Color, secondary: Color)? {
        do {
            // Attempt to process the current wallpaper to get the dominant colors.
            let dominantColors = try await processCurrentWallpaper()

            // Sort the first two colors by their brightness
            // Using brightness sorting ensures that the brighter color is used as the primary accent,
            // which typically works better for UI elements that need good contrast
            let colors = dominantColors.prefix(2).sorted(by: { $0.brightness > $1.brightness })

            // Use the first dominant color or clear if none.
            let primaryColor = Color(colors.first ?? .clear)

            // Use the second dominant color if possible, otherwise return the primary color.
            let secondaryColor = colors.count > 1 ? Color(colors[1]) : primaryColor

            logger.info("Successfully calculated dominant colors from wallpaper")

            return (primaryColor, secondaryColor)
        } catch {
            // If an error occurs, print the error description.
            logger.error("Failed to fetch wallpaper colors: \(error.localizedDescription)")
            return nil
        }
    }

    /// Processes the current wallpaper and returns the dominant colors.
    /// - Throws: A WallpaperProcessorError if the screenshot fails or dominant colors cannot be calculated.
    /// - Returns: An array of NSColor representing the dominant colors.
    ///
    /// This method coordinates the wallpaper capture and color analysis process.
    /// It first attempts to capture a screenshot of the desktop wallpaper, then
    /// passes that image to the color analysis algorithm to extract vibrant,
    /// visually distinct colors suitable for UI accents.
    private func processCurrentWallpaper() async throws -> [NSColor] {
        let wallpaperImageFetcher = WallpaperImageFetcher()

        // Take a screenshot of the main display.
        guard let screenshot = try await wallpaperImageFetcher.takeScreenshot() else {
            // If taking a screenshot fails, throw an error.
            throw WallpaperProcessorError.screenshotFailed
        }

        // Calculate the dominant colors from the screenshot.
        let dominantColors = await screenshot.calculateDominantColors()

        // Ensure that dominant colors are calculated and the array is not empty.
        guard let colors = dominantColors, !colors.isEmpty else {
            // If no colors are found, throw an error.
            throw WallpaperProcessorError.dominantColorsCalculationFailed
        }

        return colors
    }
}

// MARK: - NSImage extensions

///
/// This implementation provides an advanced color extraction algorithm that:
/// - Efficiently processes desktop wallpaper images to extract vibrant colors
/// - Prioritizes visually appealing accent colors over technically dominant ones
/// - Uses a multi-step fallback approach to ensure it works across different permission scenarios
/// - Incorporates intelligent filtering to avoid colors that would make poor UI accents
///
/// The algorithm is optimized for performance while maintaining high-quality color results.

// The real beans here (I don't like beans)
extension NSImage {
    /// Calculates the dominant colors of the image asynchronously.
    /// - Returns: An array of NSColor representing the dominant colors, or nil if an error occurs.
    /// Optimized to return only the top 2 most vibrant and visually distinct colors.
    ///
    /// This method prioritizes colors with high saturation and medium brightness to find
    /// visually appealing accent colors suitable for UI themes. The algorithm:
    /// 1. Resizes the image to improve performance
    /// 2. Samples pixels (skipping every other pixel to improve speed)
    /// 3. Uses a quantization technique to group similar colors
    /// 4. Scores colors based on both frequency and visual quality (saturation and balanced brightness)
    /// 5. Ensures the returned colors are visually distinct from each other
    ///
    /// The scoring system is designed to favor vibrant colors over dull ones, even if the
    /// dull colors appear more frequently in the image. This approach works well for extracting
    /// accent colors from wallpapers, which often have subtle variation in dominant colors.
    func calculateDominantColors() async -> [NSColor]? {
        // Resize the image to a smaller size to improve performance
        let aspectRatio = size.width / size.height
        let resizedImage = resized(to: NSSize(width: 100 * aspectRatio, height: 100))

        guard
            let resizedCGImage = resizedImage?.cgImage(forProposedRect: nil, context: nil, hints: nil),
            let dataProvider = resizedCGImage.dataProvider,
            let data = CFDataGetBytePtr(dataProvider.data)
        else {
            NSLog("Error: \(WallpaperProcessorError.imageResizeFailed)")
            return nil
        }

        let bytesPerPixel = resizedCGImage.bitsPerPixel / 8
        let bytesPerRow = resizedCGImage.bytesPerRow
        let width = resizedCGImage.width
        let height = resizedCGImage.height

        // Use a lower quantization level to better group similar colors
        // The value of 32 provides enough color differentiation while still grouping similar shades
        let quantizationLevel = 32.0

        // Use a dictionary to count color occurrences
        // We use integer keys for better performance compared to using NSColor as keys
        var colorCounts = [Int: Int]() // [ColorKey: Count]
        var colorMap = [Int: NSColor]() // [ColorKey: ActualColor]

        // Sample every 2nd pixel for better performance
        // This significantly speeds up processing with minimal impact on accuracy
        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let pixelData = Int(y * bytesPerRow + x * bytesPerPixel)

                let red = CGFloat(data[pixelData]) / 255.0
                let green = CGFloat(data[pixelData + 1]) / 255.0
                let blue = CGFloat(data[pixelData + 2]) / 255.0
                let alpha = (bytesPerPixel == 4) ? CGFloat(data[pixelData + 3]) / 255.0 : 1.0

                // Skip fully transparent pixels
                if alpha < 0.1 { continue }

                // Simple quantization - this maps similar colors to the same key
                // Converting to integers reduces memory usage and improves comparison speed
                let quantizedRed = Int(round(red * quantizationLevel))
                let quantizedGreen = Int(round(green * quantizationLevel))
                let quantizedBlue = Int(round(blue * quantizationLevel))

                // Create a unique key for this color
                // Bit-shifting creates a compact, unique integer representation of the RGB value
                let colorKey = (quantizedRed << 16) | (quantizedGreen << 8) | quantizedBlue

                // Increment the count for this color
                colorCounts[colorKey, default: 0] += 1

                // Store the original color if we haven't seen this key before
                // This preserves the original color quality rather than using the quantized version
                if colorMap[colorKey] == nil {
                    colorMap[colorKey] = NSColor(red: red, green: green, blue: blue, alpha: alpha)
                }
            }
        }

        // Calculate color vibrancy (using a combination of saturation and brightness)
        // More vibrant colors (saturated but not too dark/light) score higher
        var colorScores = [Int: Double]()
        for (colorKey, color) in colorMap {
            let count = colorCounts[colorKey] ?? 0
            guard count > 0 else { continue }

            let hsbColor = color.usingColorSpace(.deviceRGB)!
            let saturation = hsbColor.saturationComponent
            let brightness = hsbColor.brightness

            // Skip colors that are too dark or too light
            // Colors at the extreme ends of brightness tend to make poor accent colors
            if brightness < 0.15 || brightness > 0.95 {
                continue
            }

            // Calculate a score that favors vibrant colors (high saturation) but not
            // extreme brightness or darkness
            // The formula penalizes colors far from medium brightness (0.5)
            let vibrancyScore = saturation * (1.0 - abs(brightness - 0.5) * 1.5)

            // Final score combines color frequency with vibrancy
            // This balances between common colors and visually appealing ones
            let score = Double(count) * vibrancyScore
            colorScores[colorKey] = score
        }

        // Sort colors by score and get top colors
        // We get more than 2 initially because some might be filtered out as too similar
        let sortedColors = colorScores
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { colorMap[$0.key]! }

        // Ensure colors are distinct enough from each other
        // This prevents selecting variations of the same color
        var finalColors: [NSColor] = []
        for color in sortedColors {
            if finalColors.isEmpty || !finalColors.contains(where: { color.isSimilar(to: $0, threshold: 0.15) }) {
                finalColors.append(color)
                if finalColors.count >= 2 {
                    break
                }
            }
        }

        // If we couldn't find distinct vibrant colors, return the top 2 by frequency
        // This fallback ensures we always return something useful
        if finalColors.count < 2 {
            let topColors = colorCounts
                .sorted { $0.value > $1.value }
                .prefix(2)
                .compactMap { colorMap[$0.key] }
            return Array(topColors)
        }

        return finalColors
    }

    /// Helper function to resize the image to a new size.
    /// - Parameter newSize: The target size for the resized image.
    /// - Returns: The resized NSImage or nil if the operation fails.
    func resized(to newSize: NSSize) -> NSImage? {
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(newSize.width),
            pixelsHigh: Int(newSize.height), bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else {
            NSLog("Error: \(WallpaperProcessorError.bitmapCreationFailed)")
            return nil
        }
        bitmapRep.size = newSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        draw(in: NSRect(x: 0, y: 0, width: newSize.width, height: newSize.height),
             from: NSRect.zero, operation: .copy, fraction: 1.0, respectFlipped: true, hints: [NSImageRep.HintKey.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)])
        NSGraphicsContext.restoreGraphicsState()
        let resizedImage = NSImage(size: newSize)
        resizedImage.addRepresentation(bitmapRep)
        return resizedImage
    }
}
