//
//  WallpaperColors.swift
//  Loop
//
//  Created by Kami on 27/06/2024.
//

import AppKit

// The real beans here (I don't like beans)
extension NSImage {
    // Calculates the dominant colors of the image.
    func calculateDominantColors(completion: @escaping ([NSColor]?) -> ()) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Resize the image for faster processing while maintaining aspect ratio
            let aspectRatio = self.size.width / self.size.height
            // Set it to 100x100 for faster calculations
            let resizedImage = self.resized(to: NSSize(width: 100 * aspectRatio, height: 100))

            guard let resizedCGImage = resizedImage?.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  let dataProvider = resizedCGImage.dataProvider,
                  let data = CFDataGetBytePtr(dataProvider.data) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
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
            let filteredColors = self.filterSimilarColors(colors: sortedColors)

            DispatchQueue.main.async {
                completion(filteredColors)
            }
        }
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
        draw(in: NSRect(x: 0, y: 0, width: newSize.width, height: newSize.height),
             from: NSRect.zero, operation: .copy, fraction: 1.0)
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
    private static var lastProcessedColors: [NSColor]?
    private static var wallpaperCheckTimer: Timer?

    // Processes the current wallpaper and returns a message with the dominant colors.
    public static func processCurrentWallpaper(completion: @escaping (Result<[NSColor], Error>) -> ()) {
        takeScreenshot { screenshot in
            guard let image = screenshot else {
                completion(.failure(NSError(domain: "WallpaperProcessorError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to take a screenshot of the desktop wallpaper."])))
                return
            }
            image.calculateDominantColors { dominantColors in
                guard let colors = dominantColors, !colors.isEmpty else {
                    completion(.failure(NSError(domain: "WallpaperProcessorError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not calculate the dominant colors."])))
                    return
                }

                // Update lastProcessedColors with the new dominant colors
                lastProcessedColors = colors

                completion(.success(colors))
            }
        }
    }

    // Takes a screenshot of the main display.
    private static func takeScreenshot(completion: @escaping (NSImage?) -> ()) {
        let mainDisplayID = CGMainDisplayID()

        #warning("TODO: Add a switch method for CGDisplayCreateImage as it's not longer supported on macOS 14.4/15")
        // Find a method that'll work in macos 14.4/15 this no longer is supported
        guard let screenshotCGImage = CGDisplayCreateImage(mainDisplayID) else {
            completion(nil)
            return
        }

        completion(NSImage(cgImage: screenshotCGImage, size: NSSize.zero))
    }
}
