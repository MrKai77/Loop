//
//  RadialMenuController.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import SwiftUI
import Defaults

class RadialMenuController {
    
    let windowResizer = WindowResizer()
    let loopPreview = PreviewController()
    
    var currentResizingDirection: WindowResizingOptions = .noAction
    var isLoopRadialMenuShown:Bool = false
    var loopRadialMenuWindowController: NSWindowController?
    
    func showMenu() {
        if let windowController = self.loopRadialMenuWindowController {
            windowController.window?.orderFrontRegardless()
            return
        }
        
        let mouseX: CGFloat = NSEvent.mouseLocation.x
        let mouseY: CGFloat = NSEvent.mouseLocation.y
        
        let windowSize: CGFloat = 500
        
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: true,
                            screen: NSApp.keyWindow?.screen)
        panel.hasShadow = false
        panel.backgroundColor = NSColor.white.withAlphaComponent(0.00001)
        panel.level = .screenSaver
        panel.contentView = NSHostingView(rootView: RadialMenuView())
        panel.alphaValue = 0
        panel.setFrame(CGRect(x: mouseX-windowSize/2, y: mouseY-windowSize/2, width: windowSize, height: windowSize), display: false)
        panel.makeKeyAndOrderInFrontOfSpaces() // Makes window stay in same spot as you swich spaces
        
        self.loopRadialMenuWindowController = .init(window: panel)
        
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            panel.animator().alphaValue = 1
        })
    }
    
    func closeMenu() {
        guard let windowController = loopRadialMenuWindowController else { return }
        self.loopRadialMenuWindowController = nil
        
        windowController.window?.animator().alphaValue = 1
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            windowController.window?.animator().alphaValue = 0
        }, completionHandler: {
            windowController.close()
        })
    }
    
    func AddObservers() {
        NSEvent.addGlobalMonitorForEvents(matching: NSEvent.EventTypeMask.flagsChanged, handler: { (event) -> Void in
            if(Int(event.keyCode) == Defaults[.loopRadialMenuTrigger]) {  // If selected trigger key is pressed
                if(event.modifierFlags.rawValue == 256) {   // Key down event
                    self.isLoopRadialMenuShown = false
                    self.closeMenu()
                    self.loopPreview.closePreview()
                    self.windowResizer.resizeFrontmostWindowWithDirection(self.currentResizingDirection)
                } else {                                    // Key up event
                    self.isLoopRadialMenuShown = true
                    self.showMenu()
                    if (Defaults[.loopPreviewVisibility] == true) {
                        self.loopPreview.showPreview()
                        self.loopRadialMenuWindowController?.window?.makeKeyAndOrderInFrontOfSpaces()
                    }
                }
            }
        })

        NotificationCenter.default.addObserver(self, selector: #selector(self.handleCurrentResizingDirectionChanged(notification:)), name: Notification.Name.currentResizingDirectionChanged, object: nil)
    }
    
    @objc func handleCurrentResizingDirectionChanged(notification: Notification) {
        if let direction = notification.userInfo?["Direction"] as? WindowResizingOptions {
            self.currentResizingDirection = direction
        }
    }
}
