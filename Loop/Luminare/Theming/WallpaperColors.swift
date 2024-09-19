//
//  WallpaperColors.swift
//  Loop
//
//  Created by Kami on 27/06/2024.
//

import Defaults
import ScreenCaptureKit
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
            let colors = dominantColors.prefix(2).sorted(by: { $0.brightness > $1.brightness })

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
        let screen = NSScreen.screenWithMouse ?? NSScreen.main ?? NSScreen.screens[0]

        // Check the macOS version to decide the method for capturing the screen.
        if #available(macOS 14, *) {
            do {
                NSLog("Using modern method for macOS 15 and later.")
                // For macOS versions 14 and later, use the modern method, using ScreenCaptureKit.
                return try await takeScreenshotModern(screen)
            } catch {
                NSLog("Failed to capture the desktop wallpaper using the modern method: \(error.localizedDescription)")
                return nil
            }
        } else {
            NSLog("Using existing method for macOS versions below 15.")
            // For macOS versions below 14, use the existing method.
            return takeScreenshotOld(screen)
        }
    }

    @available(macOS 14, *)
    private static func takeScreenshotModern(_ screen: NSScreen) async throws -> NSImage? {
        DispatchQueue.main.async {
            // New method needs screen capture permits
            ScreenCaptureManager.requestAccess()
        }

        // Get content that is currently available for capture.
        let availableContent = try await SCShareableContent.current

        // Find potential wallpaper windows on the screen.
        let wallpaperWindows = availableContent.windows
            .filter(\.isOnScreen)
            .sorted(by: { $0.windowLayer < $1.windowLayer })
            .filter { ($0.title ?? "").contains("Wallpaper") }
            .filter { $0.owningApplication?.bundleIdentifier == "com.apple.dock" }

        // Create a content filter to capture the wallpaper windows on the screen.
        let filter = SCContentFilter(
            display: availableContent.displays.first(where: { $0.displayID == screen.displayID })!,
            including: wallpaperWindows
        )
        let config = if #available(macOS 15.0, *) { // capture HDR on macOS 15 and later
            SCStreamConfiguration(preset: .captureHDRScreenshotLocalDisplay)
        } else {
            SCStreamConfiguration()
        }
        config.showsCursor = false

        // Call the screenshot API to get CGImage representation.
        let screenshotImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        // Convert CGImage to NSImage.
        let image = NSImage(
            cgImage: screenshotImage,
            size: .init(width: screenshotImage.width, height: screenshotImage.height)
        )

        return image
    }

    private static func takeScreenshotOld(_ screen: NSScreen) -> NSImage? {
        guard let screenshotCGImage = CGDisplayCreateImage(screen.displayID!) else {
            NSLog("Failed to capture the desktop wallpaper using the existing method.")
            return nil
        }
        return NSImage(cgImage: screenshotCGImage, size: NSSize.zero)
    }
}
