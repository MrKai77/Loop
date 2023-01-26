//
//  SnapperPreview.swift
//  WindowManager
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI

class SnapperPreviewController {
    
    var snapperPreviewWindowManager: NSWindowController?
    let windowResizer = WindowResizer()
    
    func showPreview() {
        if let windowController = self.snapperPreviewWindowManager {
            windowController.window?.orderFrontRegardless()
            return
        }
        
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: true,
                            screen: NSApp.keyWindow?.screen)
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.level = .screenSaver
        panel.contentView = NSHostingView(rootView: SnapperPreviewView())
        panel.collectionBehavior = .canJoinAllSpaces
        panel.alphaValue = 0
        panel.makeKeyAndOrderInFrontOfSpaces()
        
        if let screen = windowResizer.getScreenWithMouse() {
            panel.setFrame(CGRect(x: screen.frame.minX, y: screen.frame.minY, width: screen.visibleFrame.width, height: screen.visibleFrame.height), display: false)
        }
        
        self.snapperPreviewWindowManager = .init(window: panel)
        
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            panel.animator().alphaValue = 1
        })
    }
    
    func closePreview() {
        guard let windowController = snapperPreviewWindowManager else { return }
        self.snapperPreviewWindowManager = nil
        
        windowController.window?.animator().alphaValue = 1
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            windowController.window?.animator().alphaValue = 0
        }, completionHandler: {
            windowController.close()
        })
    }
}
