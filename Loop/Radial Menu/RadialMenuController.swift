//
//  RadialMenuController.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import Defaults
import SwiftUI

class RadialMenuController {
    private var controller: NSWindowController?

    func open(position: CGPoint, frontmostWindow: Window?, startingAction: WindowAction = .init(.noAction)) {
        if let windowController = controller {
            windowController.window?.orderFrontRegardless()
            return
        }

        let mouseX: CGFloat = position.x
        let mouseY: CGFloat = position.y
        let windowSize: CGFloat = 100 + 40

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true,
            screen: NSApp.keyWindow?.screen
        )

        panel.collectionBehavior = .canJoinAllSpaces
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.level = .screenSaver
        panel.contentView = NSHostingView(
            rootView: RadialMenuView(
                window: frontmostWindow,
                startingAction: startingAction
            )
        )
        panel.alphaValue = 0
        panel.setFrameOrigin(
            NSPoint(
                x: mouseX - windowSize / 2,
                y: mouseY - windowSize / 2
            )
        )
        panel.orderFrontRegardless()

        controller = .init(window: panel)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
    }

    func close() {
        guard let windowController = controller else { return }
        controller = nil

        windowController.window?.animator().alphaValue = 1
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            windowController.window?.animator().alphaValue = 0
        }, completionHandler: {
            windowController.close()
        })
    }
}
