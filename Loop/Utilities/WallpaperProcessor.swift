//
//  WallpaperProcessor.swift
//  Loop
//
//  Created by Kami on 27/06/2024.
//

import AppKit
import Defaults
import SwiftUI

// MARK: - Wallpaper processor error

/// Represents errors that can occur during wallpaper processing.
public enum WallpaperProcessorError: Error {
    case screenshotFailed
    case dominantColorsCalculationFailed
    case noWallpaperWindowsFound
    case wallpaperWindowCaptureFailed
    case screenCaptureFailed
    case imageResizeFailed
    case bitmapCreationFailed
}

// MARK: - Wallpaper colour processor

/// IMPORTANT: FOR THE COLOR EXTRACTION FEATURE TO FUNCTION AUTOMATICALLY WITH LOOP, IT'S CRUCIAL TO GRANT
/// ACCESSIBILITY PERMISSIONS TO YOUR DEVELOPMENT VERSION OF LOOP. ADDITIONALLY, ENSURE THAT ANY PREVIOUS
/// PERMISSIONS GRANTED TO OFFICIALLY SIGNED VERSIONS OF LOOP ARE REVOKED. WITHOUT THESE STEPS, LOOP WILL
/// NOT BE ABLE TO AUTOMATICALLY FETCH WALLPAPER COLORS, AND YOU'LL BE LIMITED TO THE MANUAL EXTRACTION METHOD.
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

// MARK: - Wallpaper public function

/// Processes desktop wallpapers to extract colors for theming Loop.
/// This class provides methods to capture the current desktop wallpaper and extract
/// vibrant, visually appealing colors that can be used as accent colors in the UI.
public class WallpaperProcessor {
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
    static func fetchLatestWallpaperColors() async {
        do {
            // Attempt to process the current wallpaper to get the dominant colors.
            let dominantColors = try await processCurrentWallpaper()

            // Sort the first two colors by their brightness
            // Using brightness sorting ensures that the brighter color is used as the primary accent,
            // which typically works better for UI elements that need good contrast
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
    /// - Throws: A WallpaperProcessorError if the screenshot fails or dominant colors cannot be calculated.
    /// - Returns: An array of NSColor representing the dominant colors.
    ///
    /// This method coordinates the wallpaper capture and color analysis process.
    /// It first attempts to capture a screenshot of the desktop wallpaper, then
    /// passes that image to the color analysis algorithm to extract vibrant,
    /// visually distinct colors suitable for UI accents.
    private static func processCurrentWallpaper() async throws -> [NSColor] {
        // Take a screenshot of the main display.
        guard let screenshot = await takeScreenshot() else {
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

    /// Takes a screenshot of the main display.
    /// - Returns: An NSImage of the screenshot or nil if the operation fails.
    ///
    /// This method attempts to capture the desktop wallpaper using three approaches:
    /// 1. First, it tries to find and capture the Dock's wallpaper window directly that matches our screen dimensions
    /// 2. If that fails, it tries to capture any wallpaper window from the Dock (even if not on our exact screen)
    /// 3. As a last resort, it falls back to capturing the entire screen
    ///
    /// The direct wallpaper capture is preferred as it gets only the wallpaper without desktop icons,
    /// but requires accessibility permissions (this is accepted required for Loop, so it's fine).
    /// The fallback ensures we still get colors even if permissions aren't granted.
    private static func takeScreenshot() async -> NSImage? {
        let screen = NSScreen.screenWithMouse ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.displayBounds

        // First try to get the wallpaper window from the Dock app that matches our screen dimensions
        if let wallpaperImage = try? await captureWallpaperFromDock(screenFrame: screenFrame, matchFrame: true) {
            return wallpaperImage
        }

        // Second fallback: try to get any wallpaper window from the Dock, regardless of screen dimensions
        if let anyWallpaperImage = try? await captureWallpaperFromDock(screenFrame: screenFrame, matchFrame: false) {
            return anyWallpaperImage
        }

        // Final fallback: capture the full screen if we couldn't get any wallpaper window
        if let fallbackImage = try? await captureFullScreen() {
            return fallbackImage
        }

        NSLog("Error: \(WallpaperProcessorError.screenshotFailed)")
        return nil
    }

    /// Attempts to capture the wallpaper window from the Dock app.
    /// - Parameters:
    ///   - screenFrame: The frame of the screen to capture.
    ///   - matchFrame: Whether to match the exact screen frame dimensions or get any wallpaper window.
    /// - Returns: An NSImage of the wallpaper or nil if the operation fails.
    ///
    /// This approach uses window capturing APIs to specifically target the Dock's wallpaper window.
    /// It requires appropriate permissions, but provides the cleanest capture of just the wallpaper.
    /// The method identifies the wallpaper window by filtering window properties from the Dock process.
    private static func captureWallpaperFromDock(screenFrame: CGRect, matchFrame: Bool) async throws -> NSImage? {
        // Get all windows and filter for the Dock's wallpaper windows
        let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as! [[CFString: Any]]
        var wallpaperWindows = windows
            .filter { $0[kCGWindowOwnerName] as? String == "Dock" }
            .filter { ($0[kCGWindowName] as? String ?? "").contains("Wallpaper") }
            .filter { $0[kCGWindowIsOnscreen] as? Int == 1 }

        // Apply additional frame filtering only if matchFrame is true
        if matchFrame {
            wallpaperWindows = wallpaperWindows.filter { window in
                if let bounds = window[kCGWindowBounds] as? [String: CGFloat],
                   bounds["X"] == screenFrame.origin.x,
                   bounds["Y"] == screenFrame.origin.y,
                   bounds["Width"] == screenFrame.width,
                   bounds["Height"] == screenFrame.height {
                    true
                } else {
                    false
                }
            }
        }

        let windowIDs = wallpaperWindows.map { $0[kCGWindowNumber] as! CGWindowID }

        guard !windowIDs.isEmpty else {
            throw WallpaperProcessorError.noWallpaperWindowsFound
        }

        // Use the private CGSHWCaptureWindowList API to capture high-quality images of the windows
        // This approach provides better results than the public APIs for this specific use case
        var captureWindowIDs = windowIDs
        let cid = CGSMainConnectionID()
        let images = CGSHWCaptureWindowList(
            cid,
            &captureWindowIDs,
            captureWindowIDs.count,
            [.ignoreGlobalClipShape, .bestResolution, .fullSize]
        ).takeUnretainedValue() as! [CGImage]

        guard let image = images.first else {
            throw WallpaperProcessorError.wallpaperWindowCaptureFailed
        }

        return NSImage(cgImage: image, size: NSSize.zero)
    }

    /// Fallback method to capture the entire screen.
    /// This may include desktop icons and menubar, but it's better than nothing.
    /// - Returns: An NSImage of the screen or nil if the operation fails.
    ///
    /// This method uses the public CGWindowListCreateImage API to capture what's visible on screen.
    /// While this will include desktop icons and potentially other UI elements, it's a reliable
    /// fallback when we can't access the wallpaper window directly, and still provides
    /// useful color information in most cases.
    private static func captureFullScreen() async throws -> NSImage? {
        let screen = NSScreen.screenWithMouse ?? NSScreen.main ?? NSScreen.screens[0]
        let rect = screen.frame

        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenBelowWindow,
            kCGNullWindowID,
            [.shouldBeOpaque, .bestResolution]
        ) else {
            throw WallpaperProcessorError.screenCaptureFailed
        }

        return NSImage(cgImage: cgImage, size: NSSize.zero)
    }
}

// MARK: - Private APIs

/// Thanks to AltTab for some of the code!
/// https://github.com/lwouis/alt-tab-macos/blob/master/src/api-wrappers/private-apis/SkyLight.framework.swift

typealias CGSConnectionID = UInt32

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSHWCaptureWindowList")
func CGSHWCaptureWindowList(
    _ cid: CGSConnectionID,
    _ windowList: UnsafeMutablePointer<CGWindowID>,
    _ windowCount: Int,
    _ options: CGSWindowCaptureOptions
) -> Unmanaged<CFArray>

struct CGSWindowCaptureOptions: OptionSet {
    let rawValue: UInt32
    static let ignoreGlobalClipShape = CGSWindowCaptureOptions(rawValue: 1 << 11)
    // on a retina display, 1px is spread on 4px, so nominalResolution is 1/4 of bestResolution
    static let nominalResolution = CGSWindowCaptureOptions(rawValue: 1 << 9)
    static let bestResolution = CGSWindowCaptureOptions(rawValue: 1 << 8)
    // when Stage Manager is enabled, screenshots can become skewed. This param gets us full-size screenshots regardless
    static let fullSize = CGSWindowCaptureOptions(rawValue: 1 << 19)
}
