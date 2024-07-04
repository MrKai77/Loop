//
//  WallpaperColors.swift
//  Loop
//
//  Created by Kami on 27/06/2024.
//

import Defaults
import SwiftUI

// The real beans here (I don't like beans)
extension NSImage {
    // Calculates the dominant colors of the image.
    func calculateDominantColors() async -> [NSColor]? {
        // Resize the image for faster processing while maintaining aspect ratio
        let aspectRatio = size.width / size.height
        // Set it to 100x100 for faster calculations
        let resizedImage = resized(to: NSSize(width: 100 * aspectRatio, height: 100))

        guard
            let resizedCGImage = resizedImage?.cgImage(forProposedRect: nil, context: nil, hints: nil),
            let dataProvider = resizedCGImage.dataProvider,
            let data = CFDataGetBytePtr(dataProvider.data)
        else {
            return nil
        }

        let bytesPerPixel = resizedCGImage.bitsPerPixel / 8
        let bytesPerRow = resizedCGImage.bytesPerRow
        let width = resizedCGImage.width
        let height = resizedCGImage.height
        var colorCountMap = [NSColor: Int]()

        for y in 0 ..< height {
            for x in 0 ..< width {
                let pixelData = Int(y * bytesPerRow + x * bytesPerPixel)
                // Check for images without an alpha channel
                let alpha = (bytesPerPixel == 4) ? CGFloat(data[pixelData + 3]) / 255.0 : 1.0
                let color = NSColor(
                    red: CGFloat(data[pixelData]) / 255.0,
                    green: CGFloat(data[pixelData + 1]) / 255.0,
                    blue: CGFloat(data[pixelData + 2]) / 255.0,
                    alpha: alpha
                )
                colorCountMap[color, default: 0] += 1
            }
        }

        // Use a partial sort to find the top 2 dominant colors without sorting the entire map
        let sortedColors = colorCountMap
            .sorted { $0.value > $1.value }
            .map(\.key)

        // Filter out similar colors
        let filteredColors = filterSimilarColors(colors: sortedColors)

        return filteredColors
    }

    // Helper function to resize the image.
    func resized(to newSize: NSSize) -> NSImage? {
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(newSize.width),
            pixelsHigh: Int(newSize.height), bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }

        bitmapRep.size = newSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        draw(
            in: NSRect(x: 0, y: 0, width: newSize.width, height: newSize.height),
            from: NSRect.zero,
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        let resizedImage = NSImage(size: newSize)
        resizedImage.addRepresentation(bitmapRep)
        return resizedImage
    }

    // Helper function to filter out similar colors.
    private func filterSimilarColors(colors: [NSColor]) -> [NSColor] {
        var uniqueColors = [NSColor]()
        for color in colors {
            var isSimilar = false
            for existingColor in uniqueColors {
                if color.isSimilar(to: existingColor) {
                    isSimilar = true
                    break
                }
            }
            if !isSimilar {
                uniqueColors.append(color)
                if uniqueColors.count == 2 { break } // We only need the top 2 unique colors
            }
        }
        return uniqueColors
    }
}

// Main logic for outside scrips to ref to
public class WallpaperProcessor {
    public static func fetchLatestWallpaperColors() async {
        do {
            let colors = try await processCurrentWallpaper()
            Defaults[.customAccentColor] = Color(colors.first ?? .clear)
            Defaults[.gradientColor] = colors.count > 1 ? Color(colors[1]) : Defaults[.gradientColor]
        } catch {
            print(error.localizedDescription)
        }
    }

    // Processes the current wallpaper and returns a message with the dominant colors.
    private static func processCurrentWallpaper() async throws -> [NSColor] {
        guard let screenshot = await takeScreenshot() else {
            throw NSError(
                domain: "WallpaperProcessorError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to take a screenshot of the desktop wallpaper."]
            )
        }

        let dominantColors = await screenshot.calculateDominantColors()

        guard let colors = dominantColors, !colors.isEmpty else {
            throw NSError(
                domain: "WallpaperProcessorError",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not calculate the dominant colors."]
            )
        }

        return colors
    }

    // Takes a screenshot of the main display.
    private static func takeScreenshot() async -> NSImage? {
        let mainDisplayID = CGMainDisplayID()

        #warning("TODO: Add a switch method for CGDisplayCreateImage as it's not longer supported on macOS 14.4/15")
        guard let screenshotCGImage = CGDisplayCreateImage(mainDisplayID) else {
            return nil
        }

        return NSImage(cgImage: screenshotCGImage, size: NSSize.zero)
    }
}
