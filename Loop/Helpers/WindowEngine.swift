//
//  WindowEngine.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-16.
//

import SwiftUI
import Defaults

struct WindowEngine {

    private let kAXFullscreenAttribute = "AXFullScreen"

    func resizeFrontmostWindow(direction: WindowDirection) {
        guard let frontmostWindow = self.getFrontmostWindow() else { return }
        resize(window: frontmostWindow, direction: direction)
    }

    func getFrontmostWindow() -> AXUIElement? {

        #if DEBUG
        print("--------------------------------")
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.isActive }) else { return nil }
        print("Frontmost app: \(app)")
        guard let window = self.getFocusedWindow(pid: app.processIdentifier) else { return nil }
        print("AXUIElement: \(window)")
        print("Is kAXWindowRole: \(self.getRole(element: window) == kAXWindowRole)")
        print("Is kAXStandardWindowSubrole: \(self.getSubRole(element: window) == kAXStandardWindowSubrole)")
        #endif

        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.isActive }),
                let window = self.getFocusedWindow(pid: app.processIdentifier),
                self.getRole(element: window) == kAXWindowRole,
                self.getSubRole(element: window) == kAXStandardWindowSubrole
        else { return nil }

        return window
    }

    func resize(window: AXUIElement, direction: WindowDirection) {
        self.setFullscreen(element: window, state: false)

        let windowFrame = getRect(element: window)
        guard let screenFrame = getActiveScreenFrame(),
              let newWindowFrame = generateWindowFrame(windowFrame, screenFrame, direction)
        else { return }

        self.setPosition(element: window, position: newWindowFrame.origin)
        self.setSize(element: window, size: newWindowFrame.size)

        if self.getRect(element: window) != newWindowFrame {
            self.handleSizeConstrainedWindow(
                element: window,
                windowFrame: self.getRect(element: window),
                screenFrame: screenFrame
            )
        }

        KeybindMonitor.shared.resetPressedKeys()
    }

    private func getFocusedWindow(pid: pid_t) -> AXUIElement? {
        let element = AXUIElementCreateApplication(pid)
        guard let window = element.copyAttributeValue(attribute: kAXFocusedWindowAttribute) else { return nil }
        // swiftlint:disable force_cast
        return (window as! AXUIElement)
        // swiftlint:enable force_cast
    }
    private func getRole(element: AXUIElement) -> String? {
        return element.copyAttributeValue(attribute: kAXRoleAttribute) as? String
    }
    private func getSubRole(element: AXUIElement) -> String? {
        return element.copyAttributeValue(attribute: kAXSubroleAttribute) as? String
    }

    @discardableResult
    private func setFullscreen(element: AXUIElement, state: Bool) -> Bool {
        return element.setAttributeValue(attribute: kAXFullscreenAttribute, value: state ? kCFBooleanTrue : kCFBooleanFalse)
    }
    private func getFullscreen(element: AXUIElement) -> Bool {
        let result = element.copyAttributeValue(attribute: kAXFullscreenAttribute) as? NSNumber
        return result?.boolValue ?? false
    }

    @discardableResult
    private func setPosition(element: AXUIElement, position: CGPoint) -> Bool {
        var position = position
        if let value = AXValueCreate(AXValueType.cgPoint, &position) {
            return element.setAttributeValue(attribute: kAXPositionAttribute, value: value)
        }
        return false
    }
    private func getPosition(element: AXUIElement) -> CGPoint {
        var point: CGPoint = .zero
        guard let value = element.copyAttributeValue(attribute: kAXPositionAttribute) else { return point }
        // swiftlint:disable force_cast
        AXValueGetValue(value as! AXValue, .cgPoint, &point)    // Convert to CGPoint
        // swiftlint:enable force_cast
        return point
    }

    @discardableResult
    private func setSize(element: AXUIElement, size: CGSize) -> Bool {
        var size = size
        if let value = AXValueCreate(AXValueType.cgSize, &size) {
            return element.setAttributeValue(attribute: kAXSizeAttribute, value: value)
        }
        return false
    }
    private func getSize(element: AXUIElement) -> CGSize {
        var size: CGSize = .zero
        guard let value = element.copyAttributeValue(attribute: kAXSizeAttribute) else { return size }
        // swiftlint:disable force_cast
        AXValueGetValue(value as! AXValue, .cgSize, &size)      // Convert to CGSize
        // swiftlint:enable force_cast
        return size
    }

    private func getRect(element: AXUIElement) -> CGRect {
        return CGRect(origin: getPosition(element: element), size: getSize(element: element))
    }

    private func getActiveScreenFrame() -> CGRect? {
        guard let screen = NSScreen().screenWithMouse() else { return nil }
        guard let displayID = screen.displayID else { return nil }
        let menubarHeight = screen.frame.size.height - screen.visibleFrame.size.height
        var screenFrame = CGDisplayBounds(displayID)
        screenFrame.size.height -= menubarHeight
        screenFrame.origin.y += menubarHeight

        return screenFrame
    }
    private func generateWindowFrame(_ windowFrame: CGRect, _ screenFrame: CGRect, _ direction: WindowDirection) -> CGRect? {
        let screenWidth = screenFrame.size.width
        let screenHeight = screenFrame.size.height
        let screenX = screenFrame.origin.x
        let screenY = screenFrame.origin.y

        switch direction {
        case .maximize:
            return CGRect(x: screenX, y: screenY, width: screenWidth, height: screenHeight)
        case .center:
            return CGRect(x: screenFrame.midX - windowFrame.width/2,
                          y: screenFrame.midY - windowFrame.height/2,
                          width: windowFrame.width,
                          height: windowFrame.height)
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

    private func handleSizeConstrainedWindow(element: AXUIElement, windowFrame: CGRect, screenFrame: CGRect) {

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

        setPosition(element: element, position: fixedWindowFrame.origin)
    }
}
