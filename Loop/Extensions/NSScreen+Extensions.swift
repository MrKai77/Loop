//
//  NSScreen+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import Defaults
import SwiftUI

extension NSScreen {
    // Return the CGDirectDisplayID
    // Used in to help calculate the size a window needs to be resized to
    var displayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID
    }

    var displayMode: CGDisplayMode? {
        guard
            let id = displayID,
            let displayMode = CGDisplayCopyDisplayMode(id)
        else {
            return nil
        }

        return displayMode
    }

    static var screenWithMouse: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) })

        return screenWithMouse
    }

    var safeScreenFrame: CGRect {
        guard
            let displayID
        else {
            NSLog("Error: Failed to get NSScreen.displayID in NSScreen.safeScreenFrame")
            return frame.flipY(screen: self)
        }

        let screenFrame = CGDisplayBounds(displayID)
        let visibleFrame = stageStripFreeFrame.flipY(screen: self)

        // By setting safeScreenFrame to visibleFrame, we won't need to adjust its size.
        var safeScreenFrame = visibleFrame

        // By using visibleFrame, coordinates of multiple displays won't
        // work correctly, so we instead use screenFrame's origin.
        safeScreenFrame.origin = screenFrame.origin

        safeScreenFrame.origin.y += menubarHeight
        safeScreenFrame.origin.x -= screenFrame.minX - visibleFrame.minX

        return safeScreenFrame
    }

    var stageStripFreeFrame: NSRect {
        var frame = visibleFrame

        if Defaults[.respectStageManager],
           SystemWindowManager.StageManager.enabled,
           SystemWindowManager.StageManager.shown {
            if SystemWindowManager.StageManager.position == .leading {
                frame.origin.x += Defaults[.stageStripSize]
            }

            frame.size.width -= Defaults[.stageStripSize]
        }

        return frame
    }

    var displayBounds: CGRect {
        guard
            let displayID
        else {
            NSLog("Error: Failed to get NSScreen.displayID in NSScreen.displayBounds")
            return frame.flipY(screen: self)
        }

        return CGDisplayBounds(displayID)
    }

    var menubarHeight: CGFloat {
        frame.maxY - visibleFrame.maxY
    }

    func isSameScreen(_ other: NSScreen) -> Bool {
        displayID == other.displayID
    }
}

// MARK: - Calculate physical screen size

extension NSScreen {
    // Returns diagonal size in inches
    var diagonalSize: CGFloat {
        let unitsPerInch = unitsPerInch
        let screenSizeInInches = CGSize(
            width: frame.width / unitsPerInch.width,
            height: frame.height / unitsPerInch.height
        )

        // Just the pythagorean theorem
        let diagonalSize = sqrt(pow(screenSizeInInches.width, 2) + pow(screenSizeInInches.height, 2))

        return diagonalSize
    }

    private var unitsPerInch: CGSize {
        // We need to convert from mm to inch because CGDisplayScreenSize returns units in mm.
        let millimetersPerInch: CGFloat = 25.4

        let screenDescription = deviceDescription
        if let displayUnitSize = (screenDescription[NSDeviceDescriptionKey.size] as? NSValue)?.sizeValue,
           let screenNumber = (screenDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value {
            let displayPhysicalSize = CGDisplayScreenSize(screenNumber)

            return CGSize(
                width: millimetersPerInch * displayUnitSize.width / displayPhysicalSize.width,
                height: millimetersPerInch * displayUnitSize.height / displayPhysicalSize.height
            )
        } else {
            // this is the same as what CoreGraphics assumes if no EDID data is available from the display device
            // https://developer.apple.com/documentation/coregraphics/1456599-cgdisplayscreensize?language=objc
            return CGSize(width: 72.0, height: 72.0)
        }
    }
}

// MARK: - Screen overlap

extension NSScreen {
    private func verticalOverlap(with other: NSScreen) -> CGFloat {
        let a = frame
        let b = other.frame

        let top = max(a.minY, b.minY)
        let bottom = min(a.maxY, b.maxY)
        return max(0, bottom - top)
    }

    private func screensInSameRow(screens: [NSScreen], overlapThreshold: CGFloat = 10.0) -> [NSScreen] {
        screens.filter { verticalOverlap(with: $0) >= overlapThreshold }
    }

    func leftmostScreenInSameRow(overlapThreshold: CGFloat = 10.0) -> NSScreen {
        let sameRowScreens = screensInSameRow(screens: NSScreen.screens, overlapThreshold: overlapThreshold)

        let leftCandidates = sameRowScreens.filter { $0.frame.maxX <= self.frame.minX }

        guard !leftCandidates.isEmpty else {
            return self
        }

        var bestScreen: NSScreen? = nil
        var bestOverlap: CGFloat = -1

        for screen in leftCandidates {
            let overlap = verticalOverlap(with: screen)
            if overlap > bestOverlap || (overlap == bestOverlap && screen.frame.minX < bestScreen?.frame.minX ?? .infinity) {
                bestScreen = screen
                bestOverlap = overlap
            }
        }

        return bestScreen ?? self
    }

    func rightmostScreenInSameRow(overlapThreshold: CGFloat = 10.0) -> NSScreen {
        let sameRowScreens = screensInSameRow(screens: NSScreen.screens, overlapThreshold: overlapThreshold)

        let rightCandidates = sameRowScreens.filter { $0.frame.minX >= self.frame.maxX }

        guard !rightCandidates.isEmpty else {
            return self
        }

        var bestScreen: NSScreen? = nil
        var bestOverlap: CGFloat = -1

        for screen in rightCandidates {
            let overlap = verticalOverlap(with: screen)
            if overlap > bestOverlap || (overlap == bestOverlap && screen.frame.maxX > bestScreen?.frame.maxX ?? -.infinity) {
                bestScreen = screen
                bestOverlap = overlap
            }
        }

        return bestScreen ?? self
    }
}
