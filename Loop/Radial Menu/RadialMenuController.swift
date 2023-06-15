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
    var frontmostWindow: AXUIElement?
    
    func showRadialMenu(frontmostWindow: AXUIElement?) {
        if let windowController = loopRadialMenuWindowController {
            windowController.window?.orderFrontRegardless()
            return
        }
        
        currentResizingDirection = .noAction
        
        let mouseX: CGFloat = NSEvent.mouseLocation.x
        let mouseY: CGFloat = NSEvent.mouseLocation.y
        
        let windowSize: CGFloat = 250
        
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: true,
                            screen: NSApp.keyWindow?.screen)
        panel.hasShadow = false
        panel.backgroundColor = NSColor.white.withAlphaComponent(0.00001)
        panel.level = .screenSaver
        panel.contentView = NSHostingView(rootView: RadialMenuView(frontmostWindow: frontmostWindow, initialMousePosition: CGPoint(x: mouseX, y: mouseY)))
        panel.alphaValue = 0
        panel.setFrame(CGRect(x: mouseX-windowSize/2, y: mouseY-windowSize/2, width: windowSize, height: windowSize), display: false)
        panel.orderFrontRegardless() // Makes window stay in same spot as you swich spaces
        
        loopRadialMenuWindowController = .init(window: panel)
        
        NSAnimationContext.runAnimationGroup({ context in
            panel.animator().alphaValue = 1
        })
    }
    
    private func closeRadialMenu() {
        guard let windowController = loopRadialMenuWindowController else { return }
        loopRadialMenuWindowController = nil
        
        windowController.window?.animator().alphaValue = 1
        NSAnimationContext.runAnimationGroup({ context in
            windowController.window?.animator().alphaValue = 0
        }, completionHandler: {
            windowController.close()
        })
    }
    
    public func AddObservers() {
        NSEvent.addGlobalMonitorForEvents(matching: NSEvent.EventTypeMask.flagsChanged, handler: { event -> Void in
            if Int(event.keyCode) == Defaults[.loopRadialMenuTrigger]  {
                if event.modifierFlags.rawValue == 256 {
                    self.closeLoop()
                }
                else {
                    self.openLoop()
                }
            }
        })
        
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            self.checkEscapeKey(with: event)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleCurrentResizingDirectionChanged(notification:)), name: Notification.Name.currentResizingDirectionChanged, object: nil)
    }
    
    @objc private func handleCurrentResizingDirectionChanged(notification: Notification) {
        if let direction = notification.userInfo?["Direction"] as? WindowResizingOptions {
            currentResizingDirection = direction
        }
    }
    
    private func checkEscapeKey(with event: NSEvent) {
        if isLoopRadialMenuShown && event.keyCode == 53 {
            closeLoop(wasForceClosed: true)
        }
    }
    
    private func openLoop() {
        frontmostWindow = windowResizer.getFrontmostWindow()
        
        if Defaults[.loopPreviewVisibility] == true && frontmostWindow != nil{
            loopPreview.showPreview()
        }
        showRadialMenu(frontmostWindow: frontmostWindow)
        
        isLoopRadialMenuShown = true
    }
    
    private func closeLoop(wasForceClosed: Bool = false) {
        closeRadialMenu()
        loopPreview.closePreview()
        if wasForceClosed == false && isLoopRadialMenuShown == true && frontmostWindow != nil {
            windowResizer.resizeWindow(frontmostWindow!, with: currentResizingDirection)
        }
        
        isLoopRadialMenuShown = false
        frontmostWindow = nil
    }
}
