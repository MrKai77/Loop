//
//  PreviewController.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import Defaults
import OSLog
import SwiftUI

final class PreviewController {
    private var controller: NSWindowController?
    private var screen: NSScreen?
    private var window: Window?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.loop", category: "PreviewController")

    func open(
        screen: NSScreen,
        window: Window?,
        startingAction: WindowAction?
    ) {
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
        open(screen: newScreen, window: window, startingAction: nil)

        print("Changed preview window's screen")
    }

    func setAction(to newAction: WindowAction) {
        guard
            let windowController = controller,
            let screen,
            !newAction.direction.willChangeScreen,
            newAction.direction != .cycle
        else {
            return
        }

        /// Check screen bounds
        print("Screen frame: \(screen.frame)")
        print("Screen safeScreenFrame: \(screen.safeScreenFrame)")

        // Validate screen bounds before proceeding
        guard screen.safeScreenFrame.isFinite else {
            print("ERROR: Invalid screen bounds detected!")
            return
        }

        let targetWindowFrame = newAction.getFrame(
            window: window,
            bounds: screen.safeScreenFrame,
            screen: screen,
            isPreview: true
        )
        .flipY(maxY: NSScreen.screens[0].frame.maxY)

        // What is the screen's frame
        print("Target frame: \(targetWindowFrame)")

        // Validate target frame before setting
        guard targetWindowFrame.isFinite else {
            print("ERROR: Invalid target frame calculated!")
            return
        }

        let isCurrentlyTransparent = windowController.window?.alphaValue == 0
        let shouldBecomeTransparent = targetWindowFrame.size.area == 0

        // If the window is currently hidden, and the next action will present it.
        if isCurrentlyTransparent, !shouldBecomeTransparent {
            switch Defaults[.previewStartingPosition] {
            case .screenCenter:
                // No-op, this is the default behavior
                break
            case .radialMenu:
                // Center the preview window on the initial mouse position
                let mousePosition = LoopManager.shared.initialMousePosition
                let centerFrame: NSRect = .init(origin: mousePosition, size: .zero)
                windowController.window?.setFrame(centerFrame, display: true)
            case .actionCenter:
                // Center the preview window on the action's target frame
                let centerFrame: NSRect = .init(origin: targetWindowFrame.center, size: .zero)
                windowController.window?.setFrame(centerFrame, display: true)
            }
        }

        if let animation = Defaults[.animationConfiguration].previewTimingFunction {
            NSAnimationContext.runAnimationGroup { context in
                context.timingFunction = animation
                windowController.window?.animator().setFrame(targetWindowFrame, display: true)
                windowController.window?.animator().alphaValue = shouldBecomeTransparent ? 0 : 1
            }
        } else {
            windowController.window?.setFrame(targetWindowFrame, display: true)
            windowController.window?.alphaValue = shouldBecomeTransparent ? 0 : 1
        }

        logger.log("PreviewController: Set action to '\(newAction.getName())'")
    }
}
