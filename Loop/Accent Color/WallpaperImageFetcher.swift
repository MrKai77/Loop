//
//  WallpaperImageFetcher.swift
//  Loop
//
//  Created by Kai Azim on 2025-07-26.
//

import SwiftUI

final class WallpaperImageFetcher {
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
    func takeScreenshot() async throws -> NSImage? {
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

        throw WallpaperProcessorError.screenshotFailed
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
    private func captureWallpaperFromDock(screenFrame: CGRect, matchFrame: Bool) async throws -> NSImage? {
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
        let cid = SLSMainConnectionID()
        let images = SLSHWCaptureWindowList(
            cid,
            &captureWindowIDs,
            captureWindowIDs.count,
            [.ignoreGlobalClipShape, .bestResolution, .fullSize]
        ).takeRetainedValue() as! [CGImage]

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
    private func captureFullScreen() async throws -> NSImage? {
        let screen = NSScreen.screenWithMouse ?? NSScreen.main ?? NSScreen.screens[0]
        let rect = screen.frame

        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenBelowWindow,
            kCGNullWindowID,
            [.shouldBeOpaque, .bestResolution]
        ) else {
            throw WallpaperProcessorError.screenshotFailed
        }

        return NSImage(cgImage: cgImage, size: NSSize.zero)
    }
}

// MARK: - Private APIs

/// Thanks to AltTab for some of the code!
/// https://github.com/lwouis/alt-tab-macos/blob/master/src/api-wrappers/private-apis/SkyLight.framework.swift

typealias SLSConnectionID = UInt32

@_silgen_name("SLSMainConnectionID")
func SLSMainConnectionID() -> SLSConnectionID

@_silgen_name("SLSHWCaptureWindowList")
func SLSHWCaptureWindowList(
    _ cid: SLSConnectionID,
    _ windowList: UnsafeMutablePointer<CGWindowID>,
    _ windowCount: Int,
    _ options: SLSWindowCaptureOptions
) -> Unmanaged<CFArray>

struct SLSWindowCaptureOptions: OptionSet {
    let rawValue: UInt32
    static let ignoreGlobalClipShape = Self(rawValue: 1 << 11)
    // on a retina display, 1px is spread on 4px, so nominalResolution is 1/4 of bestResolution
    static let nominalResolution = Self(rawValue: 1 << 9)
    static let bestResolution = Self(rawValue: 1 << 8)
    // when Stage Manager is enabled, screenshots can become skewed. This param gets us full-size screenshots regardless
    static let fullSize = Self(rawValue: 1 << 19)
}
