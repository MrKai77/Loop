//
//  WindowEngine.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-16.
//

import SwiftUI
import Defaults

struct WindowEngine {
    static func resize(window: Window, direction: WindowDirection, screen: NSScreen) {
        window.setFullscreen(false)

        let oldWindowFrame = window.frame
        guard let screenFrame = screen.safeScreenFrame,
              let newWindowFrame = WindowEngine.generateWindowFrame(oldWindowFrame, screenFrame, direction)
        else { return }

        window.setFrame(newWindowFrame)

        if window.frame != newWindowFrame {
            WindowEngine.handleSizeConstrainedWindow(
                window: window,
                windowFrame: window.frame,
                screenFrame: screenFrame
            )
        }
    }

    static func getFrontmostWindow() -> Window? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.isActive }),
              let window = Window(pid: app.processIdentifier) else { return nil }

        #if DEBUG
        print("=== NEW WINDOW ===")
        print("Frontmost app: \(app)")
        print("kAXWindowRole: \(window.role ?? "N/A")")
        print("kAXStandardWindowSubrole: \(window.subrole ?? "N/A")")
        #endif

        return window
    }

    private static func generateWindowFrame(_ windowFrame: CGRect, _ screenFrame: CGRect, _ direction: WindowDirection) -> CGRect? {
        let screenWidth = screenFrame.size.width
        let screenHeight = screenFrame.size.height
        let screenX = screenFrame.origin.x
        let screenY = screenFrame.origin.y

        switch direction {
        case .maximize:
            return CGRect(x: screenX, y: screenY, width: screenWidth, height: screenHeight)
        case .center:
            return CGRect(
                x: screenFrame.midX - windowFrame.width/2,
                y: screenFrame.midY - windowFrame.height/2,
                width: windowFrame.width,
                height: windowFrame.height
            )
        case .topHalf:
            return CGRect(x: screenX, y: screenY, width: screenWidth, height: screenHeight/2)
        case .rightHalf:
            return CGRect(x: screenX+screenWidth/2, y: screenY, width: screenWidth/2, height: screenHeight)
        case .bottomHalf:
            return CGRect(x: screenX, y: screenY+screenHeight/2, width: screenWidth, height: screenHeight/2)
        case .leftHalf:
            return CGRect(x: screenX, y: screenY, width: screenWidth/2, height: screenHeight)
        case .topRightQuarter:
            return CGRect(x: screenX+screenWidth/2, y: screenY, width: screenWidth/2, height: screenHeight/2)
        case .topLeftQuarter:
            return CGRect(x: screenX, y: screenY, width: screenWidth/2, height: screenHeight/2)
        case .bottomRightQuarter:
            return CGRect(x: screenX+screenWidth/2, y: screenY+screenHeight/2, width: screenWidth/2, height: screenHeight/2)
        case .bottomLeftQuarter:
            return CGRect(x: screenX, y: screenY+screenHeight/2, width: screenWidth/2, height: screenHeight/2)
        case .rightThird:
            return CGRect(x: screenX+2*screenWidth/3, y: screenY, width: screenWidth/3, height: screenHeight)
        case .rightTwoThirds:
            return CGRect(x: screenX+screenWidth/3, y: screenY, width: 2*screenWidth/3, height: screenHeight)
        case .horizontalCenterThird:
            return CGRect(x: screenX+screenWidth/3, y: screenY, width: screenWidth/3, height: screenHeight)
        case .leftThird:
            return CGRect(x: screenX, y: screenY, width: screenWidth/3, height: screenHeight)
        case .leftTwoThirds:
            return CGRect(x: screenX, y: screenY, width: 2*screenWidth/3, height: screenHeight)
        case .topThird:
            return CGRect(x: screenX, y: screenY, width: screenWidth, height: screenHeight/3)
        case .topTwoThirds:
            return CGRect(x: screenX, y: screenY, width: screenWidth, height: 2*screenHeight/3)
        case .verticalCenterThird:
            return CGRect(x: screenX, y: screenY+screenHeight/3, width: screenWidth, height: screenHeight/3)
        case .bottomThird:
            return CGRect(x: screenX, y: screenY+2*screenHeight/3, width: screenWidth, height: screenHeight/3)
        case .bottomTwoThirds:
            return CGRect(x: screenX, y: screenY+screenHeight/3, width: screenWidth, height: 2*screenHeight/3)
        default:
            return nil
        }
    }

    private static func handleSizeConstrainedWindow(window: Window, windowFrame: CGRect, screenFrame: CGRect) {

        // If the window is fully shown on the screen
        if (windowFrame.maxX <= screenFrame.maxX) && (windowFrame.maxY <= screenFrame.maxY) {
            return
        }

        // If not, then Loop will auto re-adjust the window size to be fully shown on the screen
        var fixedWindowFrame = windowFrame

        if fixedWindowFrame.maxX > screenFrame.maxX {
            fixedWindowFrame.origin.x = screenFrame.maxX - fixedWindowFrame.width
        }

        if fixedWindowFrame.maxY > screenFrame.maxY {
            fixedWindowFrame.origin.y = screenFrame.maxY - fixedWindowFrame.height
        }

        window.setOrigin(fixedWindowFrame.origin)
    }
}
