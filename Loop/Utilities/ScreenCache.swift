//
//  ScreenCache.swift
//  Loop
//
//  Created by cipher-shad0w on 2025-09-26.
//

import AppKit

@MainActor
enum ScreenCache {
    private static var cachedScreens: [NSScreen]?
    private static var cacheTimestamp: Date?
    private static var cachedScreenCount: Int = 0
    private static let cacheValidityDuration: TimeInterval = 0.5

    static func getScreensInOrder() -> [NSScreen] {
        let currentScreenCount = NSScreen.screens.count

        // Invalidate cache if screen count changed
        if currentScreenCount != cachedScreenCount {
            invalidateCache()
            cachedScreenCount = currentScreenCount
        }

        // Return cached screens if still valid
        if let cached = cachedScreens,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidityDuration {
            return cached
        }

        // Generate new cache
        let screens = NSScreen.screens.sorted { screen1, screen2 in
            if abs(screen1.frame.origin.x - screen2.frame.origin.x) > 1.0 {
                return screen1.frame.origin.x < screen2.frame.origin.x
            }
            return screen1.frame.origin.y < screen2.frame.origin.y
        }

        cachedScreens = screens
        cacheTimestamp = Date()

        return screens
    }

    static func invalidateCache() {
        cachedScreens = nil
        cacheTimestamp = nil
        cachedScreenCount = 0
    }
}
