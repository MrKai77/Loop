//
//  PreviewController.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI

class PreviewController {

    var loopPreviewWindowController: NSWindowController?

    func show() {
        if let windowController = loopPreviewWindowController {
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
        panel.orderFrontRegardless()

        guard let screen = NSScreen.screenWithMouse else { return }
        let menubarHeight = screen.frame.size.height - screen.visibleFrame.size.height

        let screenWidth = screen.frame.size.width
        let screenHeight = screen.frame.size.height - menubarHeight
        let screenOriginX = screen.frame.origin.x
        let screenOriginY = screen.frame.origin.y

        panel.setFrame(NSRect(x: screenOriginX,
                              y: screenOriginY,
                              width: screenWidth,
                              height: screenHeight), display: false)

        loopPreviewWindowController = .init(window: panel)

        NSAnimationContext.runAnimationGroup({ _ in
            panel.animator().alphaValue = 1
        })
    }

    func close() {
        guard let windowController = loopPreviewWindowController else { return }
        loopPreviewWindowController = nil

        windowController.window?.animator().alphaValue = 1
        NSAnimationContext.runAnimationGroup({ _ in
            windowController.window?.animator().alphaValue = 0
        }, completionHandler: {
            windowController.close()
        })
    }
}
