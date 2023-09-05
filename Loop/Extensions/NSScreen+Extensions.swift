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
        guard let displayID = self.displayID else { return nil }
        let screenFrameOrigin = CGDisplayBounds(displayID).origin
        var screenFrame: CGRect = self.visibleFrame

        // Set position of the screenFrame (useful for multiple displays)
        screenFrame.origin = screenFrameOrigin

        // Move screenFrame's y origin to compensate for menubar & dock, if it's on the bottom
        screenFrame.origin.y += (self.frame.size.height - self.visibleFrame.size.height)

        // Move screenFrame's x origin when dock is shown on left/right
        screenFrame.origin.x += (self.frame.size.width - self.visibleFrame.size.width)

        return screenFrame
    }
}
