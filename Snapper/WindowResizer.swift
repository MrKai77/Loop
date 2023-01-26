//
//  WindowResizer.swift
//  WindowManager
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
    
    func resizeFrontmostWindowWithDirection(_ direction: WindowSnappingOptions) {
        guard let screen = self.getScreenWithMouse() else { return }
        let bounds = CGDisplayBounds(screen.displayID)
        let menubarHeight = NSApp.mainMenu?.menuBarHeight ?? 0
        let screenWidth = bounds.width
        let screenHeight = bounds.height - menubarHeight
        let screenOriginX = bounds.origin.x
        let screenOriginY = bounds.origin.y + menubarHeight
        
        switch direction {
        case .topHalf:
            self.resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY, width: screenWidth, height: screenHeight/2))
        case .rightHalf:
            self.resizeFrontmostWindow(CGRect(x: screenOriginX+screenWidth/2, y: screenOriginY, width: screenWidth/2, height: screenHeight))
        case .bottomHalf:
            self.resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY+screenHeight/2, width: screenWidth, height: screenHeight/2))
        case .leftHalf:
            self.resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY, width: screenWidth/2, height: screenHeight))
        case .topRightQuarter:
            self.resizeFrontmostWindow(CGRect(x: screenOriginX+screenWidth/2, y: screenOriginY, width: screenWidth/2, height: screenHeight/2))
        case .topLeftQuarter:
            self.resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY, width: screenWidth/2, height: screenHeight/2))
        case .bottomRightQuarter:
            self.resizeFrontmostWindow(CGRect(x: screenOriginX+screenWidth/2, y: screenOriginY+screenHeight/2, width: screenWidth/2, height: screenHeight/2))
        case .bottomLeftQuarter:
            self.resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY+screenHeight/2, width: screenWidth/2, height: screenHeight/2))
        case .maximize:
            self.resizeFrontmostWindow(CGRect(x: screenOriginX, y: screenOriginY, width: screenWidth, height: screenHeight))
        case .doNothing:
            return
        }
    }
    
    func resizeFrontmostWindow(_ frame: CGRect) {
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
        let windowsList = windowsListInfo as NSArray? as? [[String: AnyObject]]
        let visibleWindows = windowsList?.filter{ $0["kCGWindowLayer"] as! Int == 0 }
        let frontmostWindow = NSWorkspace.shared.frontmostApplication?.localizedName
        
        if let frontmostWindow = frontmostWindow {
            for window in visibleWindows! {
                let owner:String = window["kCGWindowOwnerName"] as! String
                let bounds = window["kCGWindowBounds"] as? [String: Int]
                let pid = window["kCGWindowOwnerPID"] as? Int32
                
                if owner == frontmostWindow {
                    print(window)
                    
                    let appRef = AXUIElementCreateApplication(pid!);
                    var value: AnyObject?
                    _ = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value)
                    
                    if let windowList = value as? [AXUIElement] {
                        if windowList.first != nil {
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
        }
    }
}
