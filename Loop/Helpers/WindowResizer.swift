//
//  WindowResizer.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import SwiftUI
import Defaults
import KeyboardShortcuts

class WindowResizer {
    
    let iconManager = IconManager()
    
    func getFrontmostWindow() -> AXUIElement? {
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
        let windowsList = windowsListInfo as? [[String: AnyObject]]
        let visibleWindows = windowsList?.filter{ $0["kCGWindowLayer"] as! Int == 0 }
        
        guard let frontmostWindow = NSWorkspace.shared.frontmostApplication?.localizedName else { return nil }

        for window in visibleWindows! where window[kCGWindowOwnerName as String] as! String == frontmostWindow {
            let windowPID = window[kCGWindowOwnerPID as String] as? Int32
            
            let windowList = self.getWindowList(for: windowPID!)
            
            return windowList.first ?? nil
        }
        
        return nil
    }
    
    func resizeFrontmostWindowFromKeybind(_ direction: WindowResizingOptions) {
        if Defaults[.useKeyboardShortcuts] {
            guard let frontmostWindow = self.getFrontmostWindow() else { return }
            self.resizeWindow(frontmostWindow, with: direction)
        }
    }

    func resizeWindow(_ window: AXUIElement, with direction: WindowResizingOptions) {
        guard let frame = directionToCGRect(direction) else { return }
        
        var position: CFTypeRef
        var size: CFTypeRef
        var newPoint: CGPoint = frame.origin
        var newSize: CGSize = frame.size
        
        size = AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!,&newSize)!
        position = AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!,&newPoint)!
        
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, size)
        
        Defaults[.timesLooped] += 1
        iconManager.checkIfUnlockedNewIcon()
        
        print("Resized: \(window)")
    }
    
    private func getWindowList(for pid: Int32) -> [AXUIElement] {
        let appRef = AXUIElementCreateApplication(pid);
        var value: AnyObject?
        _ = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value)
        
        guard let windowList = value as? [AXUIElement] else { return [] }
        
        return windowList
    }
    
    private func directionToCGRect(_ direction: WindowResizingOptions) -> CGRect? {
        guard let screen = NSScreen().screenWithMouse() else { return nil }
        let bounds = CGDisplayBounds(screen.displayID)
        let menubarHeight = screen.frame.size.height - screen.visibleFrame.size.height
        
        let screenWidth = bounds.width
        let screenHeight = bounds.height - menubarHeight
        let screenOriginX = bounds.origin.x
        let screenOriginY = bounds.origin.y + menubarHeight
        
        switch direction {
        case .topHalf:
            return CGRect(x: screenOriginX, y: screenOriginY, width: screenWidth, height: screenHeight/2)
        case .rightHalf:
            return CGRect(x: screenOriginX+screenWidth/2, y: screenOriginY, width: screenWidth/2, height: screenHeight)
        case .bottomHalf:
            return CGRect(x: screenOriginX, y: screenOriginY+screenHeight/2, width: screenWidth, height: screenHeight/2)
        case .leftHalf:
            return CGRect(x: screenOriginX, y: screenOriginY, width: screenWidth/2, height: screenHeight)
        case .topRightQuarter:
            return CGRect(x: screenOriginX+screenWidth/2, y: screenOriginY, width: screenWidth/2, height: screenHeight/2)
        case .topLeftQuarter:
            return CGRect(x: screenOriginX, y: screenOriginY, width: screenWidth/2, height: screenHeight/2)
        case .bottomRightQuarter:
            return CGRect(x: screenOriginX+screenWidth/2, y: screenOriginY+screenHeight/2, width: screenWidth/2, height: screenHeight/2)
        case .bottomLeftQuarter:
            return CGRect(x: screenOriginX, y: screenOriginY+screenHeight/2, width: screenWidth/2, height: screenHeight/2)
        case .maximize:
            return CGRect(x: screenOriginX, y: screenOriginY, width: screenWidth, height: screenHeight)
        case .rightThird:
            return CGRect(x: screenOriginX+2*screenWidth/3, y: screenOriginY, width: screenWidth/3, height: screenHeight)
        case .rightTwoThirds:
            return CGRect(x: screenOriginX+screenWidth/3, y: screenOriginY, width: 2*screenWidth/3, height: screenHeight)
        case .horizontalCenterThird:
            return CGRect(x: screenOriginX+screenWidth/3, y: screenOriginY, width: screenWidth/3, height: screenHeight)
        case .leftThird:
            return CGRect(x: screenOriginX, y: screenOriginY, width: screenWidth/3, height: screenHeight)
        case .leftTwoThirds:
            return CGRect(x: screenOriginX, y: screenOriginY, width: 2*screenWidth/3, height: screenHeight)
        case .topThird:
            return CGRect(x: screenOriginX, y: screenOriginY, width: screenWidth, height: screenHeight/3)
        case .topTwoThirds:
            return CGRect(x: screenOriginX, y: screenOriginY, width: screenWidth, height: 2*screenHeight/3)
        case .verticalCenterThird:
            return CGRect(x: screenOriginX, y: screenOriginY+screenHeight/3, width: screenWidth, height: screenHeight/3)
        case .bottomThird:
            return CGRect(x: screenOriginX, y: screenOriginY+2*screenHeight/3, width: screenWidth, height: screenHeight/3)
        case .bottomTwoThirds:
            return CGRect(x: screenOriginX, y: screenOriginY+screenHeight/3, width: screenWidth, height: 2*screenHeight/3)
            
        default:
            return nil
        }
    }
    
    func setKeybindings() {
        KeyboardShortcuts.onKeyDown(for: .maximize) { [self] in
            resizeFrontmostWindowFromKeybind(.maximize)
        }
        
        KeyboardShortcuts.onKeyDown(for: .topHalf) { [self] in
            resizeFrontmostWindowFromKeybind(.topHalf)
        }
        KeyboardShortcuts.onKeyDown(for: .rightHalf) { [self] in
            resizeFrontmostWindowFromKeybind(.rightHalf)
        }
        KeyboardShortcuts.onKeyDown(for: .bottomHalf) { [self] in
            resizeFrontmostWindowFromKeybind(.bottomHalf)
        }
        KeyboardShortcuts.onKeyDown(for: .leftHalf) { [self] in
            resizeFrontmostWindowFromKeybind(.leftHalf)
        }
        
        KeyboardShortcuts.onKeyDown(for: .topRightQuarter) { [self] in
            resizeFrontmostWindowFromKeybind(.topRightQuarter)
        }
        KeyboardShortcuts.onKeyDown(for: .topLeftQuarter) { [self] in
            resizeFrontmostWindowFromKeybind(.topLeftQuarter)
        }
        KeyboardShortcuts.onKeyDown(for: .bottomRightQuarter) { [self] in
            resizeFrontmostWindowFromKeybind(.bottomRightQuarter)
        }
        KeyboardShortcuts.onKeyDown(for: .bottomLeftQuarter) { [self] in
            resizeFrontmostWindowFromKeybind(.bottomLeftQuarter)
        }
        
        KeyboardShortcuts.onKeyDown(for: .rightThird) { [self] in
            resizeFrontmostWindowFromKeybind(.rightThird)
        }
        KeyboardShortcuts.onKeyDown(for: .rightTwoThirds) { [self] in
            resizeFrontmostWindowFromKeybind(.rightTwoThirds)
        }
        KeyboardShortcuts.onKeyDown(for: .horizontalCenterThird) { [self] in
            resizeFrontmostWindowFromKeybind(.horizontalCenterThird)
        }
        KeyboardShortcuts.onKeyDown(for: .leftThird) { [self] in
            resizeFrontmostWindowFromKeybind(.leftThird)
        }
        KeyboardShortcuts.onKeyDown(for: .leftTwoThirds) { [self] in
            resizeFrontmostWindowFromKeybind(.leftTwoThirds)
        }
    }
}
