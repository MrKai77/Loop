//
//  RadialMenuController.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import SwiftUI
import Defaults

class RadialMenuController {

    private var loopRadialMenuWindowController: NSWindowController?

    func open(frontmostWindow: Window?) {
        if let windowController = loopRadialMenuWindowController {
            windowController.window?.orderFrontRegardless()
            return
        }

        let mouseX: CGFloat = NSEvent.mouseLocation.x
        let mouseY: CGFloat = NSEvent.mouseLocation.y

        let windowSize: CGFloat = 250

        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: true,
                            screen: NSApp.keyWindow?.screen)
        panel.collectionBehavior = .canJoinAllSpaces
        panel.hasShadow = false
        panel.backgroundColor = NSColor.white.withAlphaComponent(0.00001)
        panel.level = .screenSaver
        panel.contentView = NSHostingView(
            rootView: RadialMenuView(
                frontmostWindow: frontmostWindow,
                initialMousePosition: CGPoint(x: mouseX,
                                              y: mouseY)
            )
        )
        panel.alphaValue = 0
        panel.setFrame(
            CGRect(
                x: mouseX-windowSize/2,
                y: mouseY-windowSize/2,
                width: windowSize,
                height: windowSize
            ),
            display: false
        )
        panel.orderFrontRegardless()

        loopRadialMenuWindowController = .init(window: panel)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        })
    }

    func close() {
        guard let windowController = loopRadialMenuWindowController else { return }
        loopRadialMenuWindowController = nil

        windowController.window?.animator().alphaValue = 1
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            windowController.window?.animator().alphaValue = 0
        }, completionHandler: {
            windowController.close()
        })
    }
}
