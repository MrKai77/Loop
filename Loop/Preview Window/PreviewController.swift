//
//  PreviewController.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI

class PreviewController {

    private var previewWindowController: NSWindowController?
    private var screen: NSScreen = NSScreen()

    func open(screen: NSScreen, window: Window? = nil, startingAction: WindowAction = .init(.noAction)) {
        if let windowController = previewWindowController {
            windowController.window?.orderFrontRegardless()
            return
        }
        self.screen = screen

        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: true,
                            screen: NSApp.keyWindow?.screen)
        panel.hasShadow = false
        panel.backgroundColor = NSColor.white.withAlphaComponent(0.00001)
        // This ensures that this is below the radial menu
        panel.level = NSWindow.Level(NSWindow.Level.screenSaver.rawValue - 1)
        panel.contentView = NSHostingView(
            rootView: PreviewView(
                window: window,
                startingAction: startingAction
            )
        )
        panel.collectionBehavior = .canJoinAllSpaces
        panel.alphaValue = 0
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()

        panel.setFrame(screen.stageStripFreeFrame, display: false)

        previewWindowController = .init(window: panel)

        NSAnimationContext.runAnimationGroup({ _ in
            panel.animator().alphaValue = 1
        })
    }

    func close() {
        guard let windowController = previewWindowController else { return }
        previewWindowController = nil

        windowController.window?.animator().alphaValue = 1
        NSAnimationContext.runAnimationGroup({ _ in
            windowController.window?.animator().alphaValue = 0
        }, completionHandler: {
            windowController.close()
        })
    }

    func setScreen(to screen: NSScreen) {
        self.close()
        self.open(screen: screen)
    }
}
