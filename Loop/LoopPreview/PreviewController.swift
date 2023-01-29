//
//  PreviewController.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI

class PreviewController {
    
    var loopPreviewWindowController: NSWindowController?
    let windowResizer = WindowResizer()
    
    func showPreview() {
        if let windowController = self.loopPreviewWindowController {
            windowController.window?.orderFrontRegardless()
            return
        }
        
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: true,
                            screen: NSApp.keyWindow?.screen)
        panel.hasShadow = false
        panel.backgroundColor = NSColor.white.withAlphaComponent(0.00001)
        panel.level = .screenSaver
        panel.contentView = NSHostingView(rootView: PreviewView())
        panel.collectionBehavior = .canJoinAllSpaces
        panel.alphaValue = 0
        panel.makeKeyAndOrderInFrontOfSpaces()
        
        if let screen = windowResizer.getScreenWithMouse() {
            panel.setFrame(CGRect(x: screen.frame.minX, y: screen.frame.minY, width: screen.visibleFrame.width, height: screen.visibleFrame.height), display: false)
        }
        
        self.loopPreviewWindowController = .init(window: panel)
        
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            panel.animator().alphaValue = 1
        })
    }
    
    func closePreview() {
        guard let windowController = loopPreviewWindowController else { return }
        self.loopPreviewWindowController = nil
        
        windowController.window?.animator().alphaValue = 1
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            windowController.window?.animator().alphaValue = 0
        }, completionHandler: {
            windowController.close()
        })
    }
}
