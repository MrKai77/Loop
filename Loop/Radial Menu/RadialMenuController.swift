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

    func open(position: CGPoint, frontmostWindow: Window?, startingAction: WindowAction = .init(.noAction)) {
        if let windowController = loopRadialMenuWindowController {
            windowController.window?.orderFrontRegardless()
            return
        }

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
                window: frontmostWindow,
                startingAction: startingAction
            )
        )
        panel.alphaValue = 0

        let panelRect = calculatePanelRect(position: position)
        panel.setFrame(panelRect, display: false)
        panel.orderFrontRegardless()

        loopRadialMenuWindowController = .init(window: panel)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        })
    }
    
    private func calculatePanelRect(position: CGPoint) -> CGRect {
        let windowSize: CGFloat = 250
        let radialMenuSize: CGFloat = 100

        var minX: CGFloat = 0
        var maxX: CGFloat = .infinity
        var minY: CGFloat = 0
        var maxY: CGFloat = .infinity
        
        let mouseX: CGFloat = position.x
        let mouseY: CGFloat = position.y

        if let mouseScreen = NSScreen.screenWithMouse {
            minX = mouseScreen.frame.minX
            maxX = minX + mouseScreen.frame.width
            minY = mouseScreen.frame.minY
            maxY = minY + mouseScreen.frame.height
        }
        let panelMinX = minX - (windowSize - radialMenuSize) / 2
        let panelMaxX = maxX - (windowSize - radialMenuSize) / 2 - radialMenuSize
        let panelMinY = minY - (windowSize - radialMenuSize) / 2
        let panelMaxY = maxY - (windowSize - radialMenuSize) / 2 - radialMenuSize
        let targetX = mouseX - windowSize / 2
        let targetY = mouseY - windowSize / 2

        return CGRect(
            x: targetX < panelMinX ? panelMinX : targetX > panelMaxX ? panelMaxX : targetX,
            y: targetY < panelMinY ? panelMinY : targetY > panelMaxY ? panelMaxY : targetY,
            width: windowSize,
            height: windowSize
        )
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
