//
//  PreviewController.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import Defaults
import SwiftUI

class PreviewController {
    var controller: NSWindowController?
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
        if let windowController = controller {
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
        panel.backgroundColor = .clear
        panel.setFrame(NSRect(origin: screen.stageStripFreeFrame.center, size: .zero), display: true)
        // This ensures that this is below the radial menu
        panel.level = NSWindow.Level(NSWindow.Level.screenSaver.rawValue - 1)
        panel.contentView = NSHostingView(rootView: PreviewView())
        panel.collectionBehavior = .canJoinAllSpaces
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
        controller = .init(window: panel)

        self.screen = screen
        self.window = window

        if let action = startingAction {
            setAction(to: action)
        }
    }

    func close() {
        guard let windowController = controller else { return }
        controller = nil

        windowController.window?.animator().alphaValue = 1
        NSAnimationContext.runAnimationGroup({ _ in
            windowController.window?.animator().alphaValue = 0
        }, completionHandler: {
            windowController.close()
        })
    }

    func setScreen(to newScreen: NSScreen) {
        guard
            controller != nil, // Ensures that the preview window is open
            screen != newScreen
        else {
            return
        }

        close()
        open(screen: newScreen, window: window)

        print("Changed preview window's screen")
    }

    func setAction(to action: WindowAction) {
        guard
            let windowController = controller,
            let screen,
            !action.direction.willChangeScreen,
            action.direction != .cycle
        else {
            return
        }

        let targetWindowFrame = action.getFrame(
            window: window,
            bounds: screen.safeScreenFrame,
            screen: screen,
            isPreview: true
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
