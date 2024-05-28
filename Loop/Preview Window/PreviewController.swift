//
//  PreviewController.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Defaults

class PreviewController {
    private var previewWindowController: NSWindowController?
    private var screen: NSScreen?
    private var window: Window?

    init() {
        Notification.Name.updateUIDirection.onReceive { obj in
            if let action = obj.userInfo?["action"] as? WindowAction {
                self.setAction(to: action)
            }
        }
    }

    func open(screen: NSScreen, window: Window? = nil, startingAction: WindowAction? = nil) {
        if let windowController = previewWindowController {
            windowController.window?.orderFrontRegardless()
            return
        }

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true,
            screen: NSApp.keyWindow?.screen
        )
        panel.alphaValue = 0
        panel.backgroundColor = NSColor.white.withAlphaComponent(0.00001)
        panel.setFrame(NSRect(origin: screen.stageStripFreeFrame.center, size: .zero), display: true)
        // This ensures that this is below the radial menu
        panel.level = NSWindow.Level(NSWindow.Level.screenSaver.rawValue - 1)
        panel.contentView = NSHostingView(rootView: PreviewView())
        panel.collectionBehavior = .canJoinAllSpaces
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
        previewWindowController = .init(window: panel)

        self.screen = screen
        self.window = window

        if let action = startingAction {
            self.setAction(to: action)
        }
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

    func setScreen(to newScreen: NSScreen) {
        guard
            self.previewWindowController != nil,    // Ensures that the preview window is open
            self.screen != newScreen
        else {
            return
        }

        self.close()
        self.open(screen: newScreen, window: self.window)

        print("Changed preview window's screen")
    }

    func setAction(to action: WindowAction) {
        guard
            let windowController = previewWindowController,
            let screen = self.screen,
            !action.direction.willChangeScreen,
            action.direction != .cycle
        else {
            return
        }

        let targetWindowFrame = action.getFrame(
            window: self.window,
            bounds: screen.safeScreenFrame
        )
        .flipY(maxY: NSScreen.screens[0].frame.maxY)

        let shouldBeTransparent = targetWindowFrame.size.area == 0

        if let animation = Defaults[.animationConfiguration].previewTimingFunction {
            NSAnimationContext.runAnimationGroup { context in
                context.timingFunction = animation
                windowController.window?.animator().setFrame(targetWindowFrame, display: true)
                windowController.window?.animator().alphaValue = shouldBeTransparent ? 0 : 1
            }
        } else {
            windowController.window?.setFrame(targetWindowFrame, display: true)
            windowController.window?.alphaValue = shouldBeTransparent ? 0 : 1
        }

        print("New preview window action received: \(action.direction)")
    }
}
