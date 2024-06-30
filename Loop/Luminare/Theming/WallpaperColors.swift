//
//  WallpaperColors.swift
//  Loop
//
//  Created by Kami on 27/06/2024.
//

#warning("TODO: Remove any unnecessary code - remove timing code as well for prod")

import AppKit

extension NSColor {
    // Converts NSColor to a hexadecimal string representation.
    // I think we defined this somewhere else? i can't remeber if it
    // was in Luminare or here, so i just added it apart of this file
    var toHexString: String {
        let rgbColor = usingColorSpace(.deviceRGB) ?? NSColor.black
        let red = Int(round(rgbColor.redComponent * 0xFF))
        let green = Int(round(rgbColor.greenComponent * 0xFF))
        let blue = Int(round(rgbColor.blueComponent * 0xFF))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

// The real beans here (I don't like beans)
extension NSImage {
    // Calculates the dominant colors of the image.
    func calculateDominantColors(completion: @escaping ([NSColor]?) -> ()) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Resize the image for faster processing while maintaining aspect ratio
            let aspectRatio = self.size.width / self.size.height
            // Should be able to set it to 100x100 without any issues for faster cals
            let resizedImage = self.resized(to: NSSize(width: 200 * aspectRatio, height: 200))

            guard let resizedCGImage = resizedImage?.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  let data = CFDataGetBytePtr(resizedCGImage.dataProvider!.data) else {
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
                    let color = NSColor(
                        red: CGFloat(data[pixelData]) / 255.0,
                        green: CGFloat(data[pixelData + 1]) / 255.0,
                        blue: CGFloat(data[pixelData + 2]) / 255.0,
                        alpha: CGFloat(data[pixelData + 3]) / 255.0
                    )
                    colorCountMap[color, default: 0] += 1
                }
            }

            let sortedColors = colorCountMap.sorted {
                $0.value > $1.value || ($0.value == $1.value && $0.key.brightnessComponent > $1.key.brightnessComponent)
            }.map(\.key)

            // This is filtering 5, but it can do anything
            // the console button will output 2 values though
            let dominantColors = Array(sortedColors.prefix(5))

            DispatchQueue.main.async {
                completion(dominantColors)
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
}

// Main logic for outside scrips to ref to
public class WallpaperProcessor {
    private static var lastProcessedColors: [NSColor]?
    private static var wallpaperCheckTimer: Timer?

    // A timer is the best for wallpaper checking, its currently 60 seconds
    // maybe at a later date, add advanced checking like in the system settings
    // wallpaper section ...
    
    // Starts a timer to periodically check the wallpaper.
    public static func startAutoCheckWallpaperTimer() {
        wallpaperCheckTimer?.invalidate()
        wallpaperCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            processCurrentWallpaper { result in
                print(result)
            }
        }
    }

    // Stops the wallpaper check timer.
    public static func stopAutoCheckWallpaperTimer() {
        wallpaperCheckTimer?.invalidate()
        wallpaperCheckTimer = nil
    }

    // Processes the current wallpaper and returns a message with the dominant colors.
    public static func processCurrentWallpaper(completion: @escaping (String) -> ()) {
        takeScreenshot { screenshot in
            guard let image = screenshot else {
                completion("Failed to take a screenshot of the desktop wallpaper.")
                return
            }
            image.calculateDominantColors { dominantColors in
                guard let colors = dominantColors, colors.count >= 2 else {
                    completion("Could not calculate the dominant colors.")
                    return
                }

                let topTwoColorsHex = colors.prefix(2).map(\.toHexString)
                let message = "Dominant colors: \(topTwoColorsHex.joined(separator: ", "))"
                completion(message)
            }
        }
    }

    // Takes a screenshot of the main display.
    private static func takeScreenshot(completion: @escaping (NSImage?) -> ()) {
        let mainDisplayID = CGMainDisplayID()

        // Find a method that'll work in macos 14.4/15 this no longer is supported
        guard let screenshotCGImage = CGDisplayCreateImage(mainDisplayID) else {
            completion(nil)
            return
        }

        completion(NSImage(cgImage: screenshotCGImage, size: NSSize.zero))
    }
}
