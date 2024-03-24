//
//  NSScreen+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import SwiftUI
import Defaults

extension NSScreen {

    // Return the CGDirectDisplayID
    // Used in to help calculate the size a window needs to be resized to
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

    var safeScreenFrame: CGRect {
        guard
            let displayID = self.displayID
        else {
            print("ERROR: Failed to get NSScreen.displayID in NSScreen.safeScreenFrame")
            return self.frame.flipY!
        }

        let screenFrame = CGDisplayBounds(displayID)
        let visibleFrame = self.stageStripFreeFrame.flipY(maxY: self.frame.maxY)
        let menubarHeight = visibleFrame.origin.y

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
        var frame = self.visibleFrame

        if Defaults[.respectStageManager] && StageManager.enabled && StageManager.shown {
            if StageManager.position == .leading {
                frame.origin.x += Defaults[.stageStripSize]
            }

            frame.size.width -= Defaults[.stageStripSize]
        }

        return frame
    }

    var stageStripFreeFrameRelativeToScreen: CGRect {
        let stageStripFreeFrame = self.stageStripFreeFrame.flipY(maxY: self.frame.maxY)
        let menubarHeight = stageStripFreeFrame.origin.y

        var result = stageStripFreeFrame
        result.origin = CGPoint(x: .zero, y: menubarHeight)

        return result
    }

    var displayBounds: CGRect {
        guard
            let displayID = self.displayID
        else {
            print("ERROR: Failed to get NSScreen.displayID in NSScreen.displayBounds")
            return self.frame.flipY!
        }

        return CGDisplayBounds(displayID)
    }
}
