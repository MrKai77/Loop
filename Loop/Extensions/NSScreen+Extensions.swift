//
//  NSScreen+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import SwiftUI

// Return the CGDirectDisplayID
// Used in to help calculate the size a window needs to be resized to
extension NSScreen {
    var displayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return self.deviceDescription[key] as? CGDirectDisplayID
    }

    static var screenWithMouse: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) })

        return screenWithMouse
    }

    var safeScreenFrame: CGRect? {
        guard let displayID = self.displayID,
              let visibleFrame = self.visibleFrame.flipY else { return nil }
        let screenFrame = CGDisplayBounds(displayID)
        let menubarHeight = visibleFrame.origin.y

        // By setting safeScreenFrame to visibleFrame, we won't need to adjust its size.
        var safeScreenFrame: CGRect = visibleFrame

        // By using visibleFrame, coordinates of multiple displays won't
        // work correctly, so we instead use screenFrame's origin.
        safeScreenFrame.origin = screenFrame.origin
        safeScreenFrame.origin.y += menubarHeight
        safeScreenFrame.origin.x -= screenFrame.minX - visibleFrame.minX

        return safeScreenFrame
    }
}
