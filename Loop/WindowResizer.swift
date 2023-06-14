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
    
    func resizeFrontmostWindow(_ direction: WindowResizingOptions) {
        
        guard let frame = directionToCGRect(direction) else { return }
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
        let windowsList = windowsListInfo as? [[String: AnyObject]]
        let visibleWindows = windowsList?.filter{ $0["kCGWindowLayer"] as! Int == 0 }
        
        guard let frontmostWindow = NSWorkspace.shared.frontmostApplication?.localizedName else { return }
                
        for window in visibleWindows! where window[kCGWindowOwnerName as String] as! String == frontmostWindow {
            let windowPID = window[kCGWindowOwnerPID as String] as? Int32
            
            let windowList = getWindowList(for: windowPID!)
            
            resizeWindow(windowList.first!, withFrame: frame)
        }
        
        Defaults[.timesLooped] += 1
        iconManager.checkIfUnlockedNewIcon()
    }

    private func getWindowList(for pid: Int32) -> [AXUIElement] {
        let appRef = AXUIElementCreateApplication(pid);
        var value: AnyObject?
        _ = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value)
        
        guard let windowList = value as? [AXUIElement] else { return [] }
        
        return windowList
    }

    private func resizeWindow(_ window: AXUIElement, withFrame frame: CGRect) {
        var position: CFTypeRef
        var size: CFTypeRef
        var newPoint: CGPoint = frame.origin
        var newSize: CGSize = frame.size
        
        size = AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!,&newSize)!;
        position = AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!,&newPoint)!;
        
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position);
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, size);
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
            resizeFrontmostWindow(.maximize)
        }
        
        KeyboardShortcuts.onKeyDown(for: .topHalf) { [self] in
            resizeFrontmostWindow(.topHalf)
        }
        KeyboardShortcuts.onKeyDown(for: .rightHalf) { [self] in
            resizeFrontmostWindow(.rightHalf)
        }
        KeyboardShortcuts.onKeyDown(for: .bottomHalf) { [self] in
            resizeFrontmostWindow(.bottomHalf)
        }
        KeyboardShortcuts.onKeyDown(for: .leftHalf) { [self] in
            resizeFrontmostWindow(.leftHalf)
        }
        
        KeyboardShortcuts.onKeyDown(for: .topRightQuarter) { [self] in
            resizeFrontmostWindow(.topRightQuarter)
        }
        KeyboardShortcuts.onKeyDown(for: .topLeftQuarter) { [self] in
            resizeFrontmostWindow(.topLeftQuarter)
        }
        KeyboardShortcuts.onKeyDown(for: .bottomRightQuarter) { [self] in
            resizeFrontmostWindow(.bottomRightQuarter)
        }
        KeyboardShortcuts.onKeyDown(for: .bottomLeftQuarter) { [self] in
            resizeFrontmostWindow(.bottomLeftQuarter)
        }
        
        KeyboardShortcuts.onKeyDown(for: .rightThird) { [self] in
            resizeFrontmostWindow(.rightThird)
        }
        KeyboardShortcuts.onKeyDown(for: .rightTwoThirds) { [self] in
            resizeFrontmostWindow(.rightTwoThirds)
        }
        KeyboardShortcuts.onKeyDown(for: .horizontalCenterThird) { [self] in
            resizeFrontmostWindow(.horizontalCenterThird)
        }
        KeyboardShortcuts.onKeyDown(for: .leftThird) { [self] in
            resizeFrontmostWindow(.leftThird)
        }
        KeyboardShortcuts.onKeyDown(for: .leftTwoThirds) { [self] in
            resizeFrontmostWindow(.leftTwoThirds)
        }
    }
}
