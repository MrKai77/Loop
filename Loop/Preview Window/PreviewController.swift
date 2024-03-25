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
        Notification.Name.updateUIDirection.onRecieve { obj in
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
            contentRect: NSRect(origin: screen.stageStripFreeFrame.center, size: .zero),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true,
            screen: NSApp.keyWindow?.screen
        )
        panel.hasShadow = false
        panel.backgroundColor = NSColor.white.withAlphaComponent(0.00001)

        // This ensures that this is below the radial menu
        panel.level = NSWindow.Level(NSWindow.Level.screenSaver.rawValue - 1)
        panel.contentView = NSHostingView(rootView: PreviewView())
        panel.collectionBehavior = .canJoinAllSpaces
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
        previewWindowController = .init(window: panel)

        NSAnimationContext.runAnimationGroup({ _ in
            panel.animator().alphaValue = 1
        })

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
            !action.direction.isPresetCyclable,
            !action.direction.willChangeScreen,
            action.direction != .cycle
        else {
            return
        }
//
////        if self.currentAction.direction == .undo, let window = window {
////            self.currentAction = WindowRecords.getLastAction(for: window) ?? .init(.noAction)
////        }

        let targetWindowFrame = action.getFrame(window: self.window, bounds: screen.safeScreenFrame).toAppKit()

        NSAnimationContext.runAnimationGroup { context in
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0, 0.25, 1)
            windowController.window?.animator().setFrame(targetWindowFrame, display: true)
        }

        print("New preview window action recieved: \(action.direction)")
    }
}
