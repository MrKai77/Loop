//
//  WindowResizer.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import Cocoa

class WindowResizer {
    func getScreenWithMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) })

        return screenWithMouse
    }
    
    func resizeFrontmostWindowWithDirection(_ direction: WindowResizingOptions) {
        guard let screen = self.getScreenWithMouse() else { return }
        let bounds = CGDisplayBounds(screen.displayID)
        let menubarHeight = NSApp.mainMenu?.menuBarHeight ?? 0
        let screenWidth = bounds.width
        let screenHeight = bounds.height - menubarHeight
        let screenOriginX = bounds.origin.x
        let screenOriginY = bounds.origin.y + menubarHeight
        
        switch direction {
        case .topHalf:
            resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY, width: screenWidth, height: screenHeight/2))
        case .rightHalf:
            resizeFrontmostWindow(CGRect(x: screenOriginX+screenWidth/2, y: screenOriginY, width: screenWidth/2, height: screenHeight))
        case .bottomHalf:
            resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY+screenHeight/2, width: screenWidth, height: screenHeight/2))
        case .leftHalf:
            resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY, width: screenWidth/2, height: screenHeight))
        case .topRightQuarter:
            resizeFrontmostWindow(CGRect(x: screenOriginX+screenWidth/2, y: screenOriginY, width: screenWidth/2, height: screenHeight/2))
        case .topLeftQuarter:
            resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY, width: screenWidth/2, height: screenHeight/2))
        case .bottomRightQuarter:
            resizeFrontmostWindow(CGRect(x: screenOriginX+screenWidth/2, y: screenOriginY+screenHeight/2, width: screenWidth/2, height: screenHeight/2))
        case .bottomLeftQuarter:
            resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY+screenHeight/2, width: screenWidth/2, height: screenHeight/2))
        case .maximize:
            resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY, width: screenWidth, height: screenHeight))
        case .rightThird:
            resizeFrontmostWindow(CGRect(x: screenOriginX+2*screenWidth/3, y: screenOriginY, width: screenWidth/3, height: screenHeight))
        case .rightTwoThirds:
            resizeFrontmostWindow(CGRect(x: screenOriginX+screenWidth/3, y: screenOriginY, width: 2*screenWidth/3, height: screenHeight))
        case .RLcenterThird:
            resizeFrontmostWindow(CGRect(x: screenOriginX+screenWidth/3, y: screenOriginY, width: screenWidth/3, height: screenHeight))
        case .leftThird:
            resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY, width: screenWidth/3, height: screenHeight))
        case .leftTwoThirds:
            resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY, width: 2*screenWidth/3, height: screenHeight))
        case .topThird:
            resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY, width: screenWidth, height: screenHeight/3))
        case .topTwoThirds:
            resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY, width: screenWidth, height: 2*screenHeight/3))
        case .TBcenterThird:
            resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY+screenHeight/3, width: screenWidth, height: screenHeight/3))
        case .bottomThird:
            resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY+2*screenHeight/3, width: screenWidth, height: screenHeight/3))
        case .bottomTwoThirds:
            resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY+screenHeight/3, width: screenWidth, height: 2*screenHeight/3))
            
        default:
            return
        }
    }
    
    func resizeFrontmostWindow(_ frame: CGRect) {
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
        let windowsList = windowsListInfo as NSArray? as? [[String: AnyObject]]
        let visibleWindows = windowsList?.filter{ $0["kCGWindowLayer"] as! Int == 0 }
        
        guard let frontmostWindow = NSWorkspace.shared.frontmostApplication?.localizedName else { return }
                
        for window in visibleWindows! {
            let windowOwnerName:String = window["kCGWindowOwnerName"] as! String
            let windowPID = window["kCGWindowOwnerPID"] as? Int32
            
            if windowOwnerName == frontmostWindow {
                print(window)
                
                let appRef = AXUIElementCreateApplication(windowPID!);
                var value: AnyObject?
                _ = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value)
                
                guard let windowList = value as? [AXUIElement] else { return }
                
                var position : CFTypeRef
                var size : CFTypeRef
                var newPoint: CGPoint = frame.origin
                var newSize: CGSize = frame.size
                
                size = AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!,&newSize)!;
                position = AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!,&newPoint)!;
                
                AXUIElementSetAttributeValue(windowList.first!, kAXPositionAttribute as CFString, position);
                AXUIElementSetAttributeValue(windowList.first!, kAXSizeAttribute as CFString, size);
            }
        }
    }
}
