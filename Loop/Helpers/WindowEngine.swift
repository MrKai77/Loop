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
        guard let screenFrame = screen.safeScreenFrame else { return }
        guard var targetWindowFrame = WindowEngine.generateWindowFrame(oldWindowFrame, screenFrame, direction) else { return }
        targetWindowFrame = WindowEngine.applyPadding(targetWindowFrame, direction)

        // Calculate the window's minimum window size and change the target accordingly
        window.getMinSize(screen: screen) { minSize in
            if (targetWindowFrame.minX + minSize.width) > screen.frame.maxX {
                targetWindowFrame.origin.x = screen.frame.maxX - minSize.width - Defaults[.windowPadding]
            }

            if (targetWindowFrame.minY + minSize.height) > screen.frame.maxY {
                targetWindowFrame.origin.y = screen.frame.maxY - minSize.height - Defaults[.windowPadding]
            }

            // Resize window
            window.setFrame(targetWindowFrame, animate: Defaults[.animateWindowResizes])
        }
    }

    static func getFrontmostWindow() -> Window? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.isActive }),
              let window = Window(pid: app.processIdentifier) else { return nil }

        #if DEBUG
        print("===== NEW WINDOW =====")
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

    private static func applyPadding(_ windowFrame: CGRect, _ direction: WindowDirection) -> CGRect {
        var paddingAppliedRect = windowFrame
        for side in [Edge.top, Edge.bottom, Edge.leading, Edge.trailing] {
            if direction.sidesThatTouchScreen.contains(side) {
                paddingAppliedRect.inset(side, amount: Defaults[.windowPadding])
            } else {
                paddingAppliedRect.inset(side, amount: Defaults[.windowPadding] / 2)
            }
        }
        return paddingAppliedRect
    }
}

extension CGRect {
    mutating func inset(_ side: Edge, amount: CGFloat) {
        switch side {
        case .top:
            self.origin.y += amount
            self.size.height -= amount
        case .leading:
            self.origin.x += amount
            self.size.width -= amount
        case .bottom:
            self.size.height -= amount
        case .trailing:
            self.size.width -= amount
        }
    }
}
