//
//  PreviewController.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI

class PreviewController {

    var loopPreviewWindowController: NSWindowController?

    func open(screen: NSScreen, window: Window?) {
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
        panel.contentView = NSHostingView(rootView: PreviewView(window: window))
        panel.collectionBehavior = .canJoinAllSpaces
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        panel.setFrame(screen.visibleFrame, display: false)

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
