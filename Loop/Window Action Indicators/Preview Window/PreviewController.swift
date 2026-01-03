//
//  PreviewController.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import Defaults
import Scribe
import SwiftUI

final class PreviewController {
    private var controller: NSWindowController?
    private var viewModel: PreviewViewModel?

    private var screen: NSScreen?
    private var window: Window?

    func open(
        screen: NSScreen,
        window: Window?,
        startingAction: WindowAction?
    ) {
        if let windowController = controller {
            windowController.window?.orderFrontRegardless()
            return
        }

        let viewModel = PreviewViewModel(window: window)
        self.viewModel = viewModel

        self.screen = screen
        self.window = window

        let panel = ActivePanel(
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
        panel.contentView = NSHostingView(rootView: PreviewView(viewModel: viewModel))
        panel.collectionBehavior = .canJoinAllSpaces
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
        controller = .init(window: panel)

        if let action = startingAction {
            setAction(to: action)
        }
    }

    func close() {
        guard let windowController = controller else { return }
        let window = windowController.window
        controller = nil

        if window?.alphaValue == 0 {
            windowController.close()
            return
        }

        let animationConfiguration = Defaults[.animationConfiguration]
        if let timingFunction = animationConfiguration.previewTimingFunction {
            window?.alphaValue = 1

            NSAnimationContext.runAnimationGroup { context in
                context.timingFunction = timingFunction
                context.duration = animationConfiguration.previewTimingDuration * 2
                window?.animator().alphaValue = 0
            } completionHandler: {
                windowController.close()
            }
        } else {
            windowController.close()
        }
    }

    func setWindow(to newWindow: Window) {
        window = newWindow
        viewModel?.setWindow(to: newWindow)
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

        Log.info("Changed preview window's screen", category: .previewController)
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
        Log.info("Screen frame: \(screen.frame.debugDescription)", category: .previewController)
        Log.info("Screen safeScreenFrame: \(screen.safeScreenFrame.debugDescription)", category: .previewController)

        // Validate screen bounds before proceeding
        guard screen.safeScreenFrame.isFinite else {
            Log.error("Invalid screen bounds detected", category: .previewController)
            return
        }

        var targetWindowFrame = newAction.getFrame(
            window: window,
            bounds: screen.safeScreenFrame,
            screen: screen,
            isPreview: true
        )
        .flipY(maxY: NSScreen.screens[0].frame.maxY)

        // What is the screen's frame
        Log.info("Target frame: \(targetWindowFrame.debugDescription)", category: .previewController)

        // Validate target frame before setting
        guard targetWindowFrame.isFinite else {
            Log.info("Invalid target frame calculated", category: .previewController)
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
                // Center the preview window on the action's target frame (at 80% size)
                let previewWidth = targetWindowFrame.width * 0.8
                let previewHeight = targetWindowFrame.height * 0.8

                let centerFrame: NSRect = .init(
                    x: targetWindowFrame.center.x - (previewWidth / 2),
                    y: targetWindowFrame.center.y - (previewHeight / 2),
                    width: previewWidth,
                    height: previewHeight
                )

                windowController.window?.setFrame(centerFrame, display: true)
            }
        }

        if !isCurrentlyTransparent, shouldBecomeTransparent, let currentFrame = windowController.window?.frame {
            // Center the preview window on the last target frame (at 80% size)
            let scaledWidth = currentFrame.width * 0.8
            let scaledHeight = currentFrame.height * 0.8

            targetWindowFrame = .init(
                x: currentFrame.center.x - (scaledWidth / 2),
                y: currentFrame.center.y - (scaledHeight / 2),
                width: scaledWidth,
                height: scaledHeight
            )
        }

        let animationConfiguration = Defaults[.animationConfiguration]
        if let timingFunction = animationConfiguration.previewTimingFunction {
            NSAnimationContext.runAnimationGroup { context in
                context.timingFunction = timingFunction
                context.duration = animationConfiguration.previewTimingDuration
                windowController.window?.animator().setFrame(targetWindowFrame, display: true)
                windowController.window?.animator().alphaValue = shouldBecomeTransparent ? 0 : 1
            }
        } else {
            windowController.window?.setFrame(targetWindowFrame, display: true)
            windowController.window?.alphaValue = shouldBecomeTransparent ? 0 : 1
        }

        Log.ui("Set action to '\(newAction.description)'", category: .previewController)
    }
}
