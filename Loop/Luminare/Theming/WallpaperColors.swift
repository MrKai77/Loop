//
//  WallpaperColors.swift
//  Loop
//
//  Created by Kami on 27/06/2024.
//

import Defaults
import SwiftUI

// MARK: - Wallpaper colour processor

/// IMPORTANT: FOR THE COLOR EXTRACTION FEATURE TO FUNCTION AUTOMATICALLY WITH LOOP, IT'S CRUCIAL TO GRANT
/// ACCESSIBILITY PERMISSIONS TO YOUR DEVELOPMENT VERSION OF LOOP. ADDITIONALLY, ENSURE THAT ANY PREVIOUS
/// PERMISSIONS GRANTED TO OFFICIALLY SIGNED VERSIONS OF LOOP ARE REVOKED. WITHOUT THESE STEPS, LOOP WILL
/// NOT BE ABLE TO AUTOMATICALLY FETCH WALLPAPER COLORS, AND YOU'LL BE LIMITED TO THE MANUAL EXTRACTION METHOD.

// The real beans here (I don't like beans)
extension NSImage {
    /// Calculates the dominant colors of the image asynchronously.
    /// - Returns: An array of NSColor representing the dominant colors, or nil if an error occurs.
    /// Resizing the image to a smaller size improves performance by reducing the number of pixels that need to be analyzed.
    /// NOTE: This function tends to return darker colors, which can be problematic with darker wallpapers. To address this,
    /// a brightness threshold is applied to filter out excessively dark colors. Additionally, the function filters out colors
    /// that are very similar to each other, such as #000000 and #010101, to ensure a more diverse and representative color palette.
    func calculateDominantColors() async -> [NSColor]? {
        // Resize the image to a smaller size to improve performance of color calculation.
        let aspectRatio = size.width / size.height
        // Changing the aspect ratio will make it faster, but can also make it less accurate.
        // I recommend 100x100 or 200x200.
        let resizedImage = resized(to: NSSize(width: 200 * aspectRatio, height: 200))

        // Ensure we can get the CGImage and its data provider from the resized image.
        guard
            let resizedCGImage = resizedImage?.cgImage(forProposedRect: nil, context: nil, hints: nil),
            let dataProvider = resizedCGImage.dataProvider,
            let data = CFDataGetBytePtr(dataProvider.data)
        else {
            NSLog("Error: Unable to get CGImage or its data provider from the resized image.")
            return nil
        }

        // Calculate the number of bytes per pixel and per row to access pixel data correctly.
        let bytesPerPixel = resizedCGImage.bitsPerPixel / 8
        let bytesPerRow = resizedCGImage.bytesPerRow
        let width = resizedCGImage.width
        let height = resizedCGImage.height
        var colorCountMap = [NSColor: Int]()

        // Iterate over each pixel to count color occurrences.
        for y in 0 ..< height {
            for x in 0 ..< width {
                let pixelData = Int(y * bytesPerRow + x * bytesPerPixel)
                let alpha = (bytesPerPixel == 4) ? CGFloat(data[pixelData + 3]) / 255.0 : 1.0
                // Create an NSColor instance for the current pixel using RGBA values.
                var color = NSColor(
                    red: CGFloat(data[pixelData]) / 255.0,
                    green: CGFloat(data[pixelData + 1]) / 255.0,
                    blue: CGFloat(data[pixelData + 2]) / 255.0,
                    alpha: alpha
                )
                // Apply a quantization method to the color to reduce the color space complexity.
                color = color.quantized()
                // Increment the count for this color in the map.
                colorCountMap[color, default: 0] += 1
            }
        }

        // Filter out very dark colors based on a brightness threshold to avoid the dominance of dark shades.
        /// If you're using the saturation value, you can adjust this to 0.3 to get less dark colors
        /// again, but be aware of darker wallpapers.
        let brightnessThreshold: CGFloat = 0.2 // Ensure that the chosen color won't be too dark.
        /// Filtering by saturation is good for some cases; however, in the case of a black wallpaper,
        /// it will return #ED5A53 & #873D39, which does not match black.
        // let saturationThreshold: CGFloat = 0.1 // Try to ensure that the chosen color won't be bright white.
        let filteredByBrightness = colorCountMap
            .filter { $0.key.brightness > brightnessThreshold }
        // .filter { $0.key.saturationComponent > saturationThreshold }
        /// Using only the brightness will allow us to return close to perfect colors.
        /// For example, the black wallpaper from above, which previously gave #ED5A53 & #873D39,
        /// is now returning #555555 & #353535, which matches the black/gray grained wallpaper in
        /// tests used. If you need a perfect method, this can work, but it is designed for
        /// beautiful colors and pure speed. It's not a 1:1 accurate method, although, removing the
        /// filtering and color sorting brings you pretty close to a 1:1 color match.

        // If all colors are dark and the filtered map is empty, fallback to the original map.
        let finalColors = filteredByBrightness.isEmpty ? colorCountMap : filteredByBrightness

        // Sort the colors by occurrence to find the most dominant colors.
        let sortedColors = finalColors.sorted { $0.value > $1.value }.map(\.key)

        // Further filter out colors that are too similar to each other to ensure a diverse color palette.
        let distinctColors = filterSimilarColors(colors: sortedColors)

        return distinctColors
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
            NSLog("Error: Unable to create NSBitmapImageRep for new size.")
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

    /// Filters out similar colors from an array, leaving only distinct colors.
    /// - Parameter colors: The array of NSColor to filter.
    /// - Returns: An array of NSColor with similar colors removed.
    private func filterSimilarColors(colors: [NSColor]) -> [NSColor] {
        var uniqueColors = [NSColor]()
        // Iterate through the colors to build an array of unique colors.
        for color in colors {
            var isSimilar = false
            for existingColor in uniqueColors {
                // Check if the current color is similar to any already in the array.
                if color.isSimilar(to: existingColor) {
                    isSimilar = true
                    break
                }
            }
            // If the color is not similar to any existing colors, add it to the array.
            if !isSimilar {
                uniqueColors.append(color)
                // Stop if we have the top 2 unique colors.
                if uniqueColors.count == 2 { break }
            }
        }
        return uniqueColors
    }
}

// MARK: - Wallpaper public function

public class WallpaperProcessor {
    /// Fetches the latest wallpaper colors and updates the app's theme settings.
    static func fetchLatestWallpaperColors() async {
        do {
            // Attempt to process the current wallpaper to get the dominant colors.
            let dominantColors = try await processCurrentWallpaper()

            // Sort the first two colors by their brightness
            let colors = dominantColors[0...1].sorted(by: { $0.brightness > $1.brightness })

            // Update the custom accent color with the first dominant color or clear if none.
            Defaults[.customAccentColor] = Color(colors.first ?? .clear)
            // Update the gradient color with the second dominant color or the existing gradient color if only one color is found.
            Defaults[.gradientColor] = colors.count > 1 ? Color(colors[1]) : Defaults[.gradientColor]
        } catch {
            // If an error occurs, print the error description.
            print(error.localizedDescription)
        }
    }

    /// Processes the current wallpaper and returns the dominant colors.
    /// - Throws: An error if the screenshot fails or dominant colors cannot be calculated.
    /// - Returns: An array of NSColor representing the dominant colors.
    private static func processCurrentWallpaper() async throws -> [NSColor] {
        // Take a screenshot of the main display.
        guard let screenshot = await takeScreenshot() else {
            // If taking a screenshot fails, throw an error.
            throw NSError(
                domain: "WallpaperProcessorError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to take a screenshot of the desktop wallpaper."]
            )
        }

        // Calculate the dominant colors from the screenshot.
        let dominantColors = await screenshot.calculateDominantColors()

        // Ensure that dominant colors are calculated and the array is not empty.
        guard let colors = dominantColors, !colors.isEmpty else {
            // If no colors are found, throw an error.
            throw NSError(
                domain: "WallpaperProcessorError",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not calculate the dominant colors."]
            )
        }

        return colors
    }

    /// Takes a screenshot of the main display.
    /// - Returns: An NSImage of the screenshot or nil if the operation fails.
    private static func takeScreenshot() async -> NSImage? {
        // Get the ID of the main display.
        let mainDisplayID = CGMainDisplayID()

        #warning("TODO: Add a switch method for CGDisplayCreateImage as it's not supported on macOS 14.4/15")
        // Attempt to create an image from the main display.
        guard let screenshotCGImage = CGDisplayCreateImage(mainDisplayID) else {
            // If the creation fails, return nil.
            return nil
        }

        // Return an NSImage created from the CGImage of the screenshot.
        return NSImage(cgImage: screenshotCGImage, size: NSSize.zero)
    }
}
