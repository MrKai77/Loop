//
//  RadialMenu.swift
//  WindowManager
//
//  Created by Kai Azim on 2023-01-23.
//

import SwiftUI
import Defaults

class RadialMenuController {
    
    let windowResizer = WindowResizer()
    let snapperPreview = SnapperPreviewController()
    
    var currentSnappingDirection: WindowSnappingOptions = .doNothing
    var isInSnappingMode:Bool = false
    var snapperPopupWindowManager: NSWindowController?
    
    func showMenu() {
        if let windowController = self.snapperPopupWindowManager {
            windowController.window?.orderFrontRegardless()
            return
        }
        
        let mouseX: CGFloat = NSEvent.mouseLocation.x
        let mouseY: CGFloat = NSEvent.mouseLocation.y
        
        let windowSize: CGFloat = 200
        
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: true,
                            screen: NSApp.keyWindow?.screen)
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.level = .screenSaver
        panel.contentView = NSHostingView(rootView: RadialMenuView())
        panel.alphaValue = 0
        panel.setFrame(CGRect(x: mouseX-100, y: mouseY-100, width: windowSize, height: windowSize), display: false)
        panel.makeKeyAndOrderInFrontOfSpaces() // Makes window stay in same spot as you swich spaces
        
        self.snapperPopupWindowManager = .init(window: panel)
        
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            panel.animator().alphaValue = 1
        })
    }
    
    func closeMenu() {
        guard let windowController = snapperPopupWindowManager else { return }
        self.snapperPopupWindowManager = nil
        
        windowController.window?.animator().alphaValue = 1
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            windowController.window?.animator().alphaValue = 0
        }, completionHandler: {
            windowController.close()
        })
    }
    
    func AddObservers() {
        NSEvent.addGlobalMonitorForEvents(matching: NSEvent.EventTypeMask.flagsChanged, handler: { (event) -> Void in
//            print(event.modifierFlags.rawValue)
            if (event.modifierFlags.description == "" && self.isInSnappingMode == true) {
                self.isInSnappingMode = false
                self.closeMenu()
                self.snapperPreview.closePreview()
                self.windowResizer.resizeFrontmostWindowWithDirection(self.currentSnappingDirection)
            } else if (event.modifierFlags.rawValue == Defaults[.snapperTrigger]) {
                self.isInSnappingMode = true
                self.showMenu()
                if (Defaults[.showPreviewWhenSnapping] == true) {
                    self.snapperPreview.showPreview()
                }
            }
        })

        NotificationCenter.default.addObserver(self, selector: #selector(self.handleCurrentSnappingDirectionChanged(notification:)), name: Notification.Name.currentSnappingDirectionChanged, object: nil)
    }
    
    @objc func handleCurrentSnappingDirectionChanged(notification: Notification) {
        if let direction = notification.userInfo?["Direction"] as? WindowSnappingOptions {
            self.currentSnappingDirection = direction
        }
    }
}
