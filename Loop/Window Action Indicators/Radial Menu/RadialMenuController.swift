//
//  RadialMenuController.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import Defaults
import OSLog
import SwiftUI

final class RadialMenuController {
    private var controller: NSWindowController?
    private var viewModel: RadialMenuViewModel?
    private let logger = Logger(category: "RadialMenuController")

    func open(
        position: CGPoint,
        window: Window?,
        startingAction: WindowAction?
    ) {
        if let windowController = controller {
            windowController.window?.orderFrontRegardless()
            return
        }

        let viewModel = RadialMenuViewModel(
            startingAction: startingAction,
            window: window,
            previewMode: false
        )
        self.viewModel = viewModel

        let mouseX: CGFloat = position.x
        let mouseY: CGFloat = position.y
        let windowSize: CGFloat = 100 + 40

        let panel = ActivePanel(
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
        panel.contentView = NSHostingView(rootView: RadialMenuView(viewModel: viewModel))
        panel.alphaValue = 0

        // Position the panel
        if Defaults[.lockRadialMenuToCenter], let screen = NSApp.keyWindow?.screen ?? NSScreen.main {
            // Position at the center of the screen
            let screenFrame = screen.frame
            panel.setFrameOrigin(
                NSPoint(
                    x: screenFrame.midX - windowSize / 2,
                    y: screenFrame.midY - windowSize / 2
                )
            )
        } else {
            // Position at the mouse cursor
            panel.setFrameOrigin(
                NSPoint(
                    x: mouseX - windowSize / 2,
                    y: mouseY - windowSize / 2
                )
            )
        }

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
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            windowController.window?.animator().alphaValue = 0
        } completionHandler: {
            windowController.close()
        }
    }

    func setAction(to newAction: WindowAction) {
        viewModel?.setAction(to: newAction)

        logger.log("RadialMenuController: Set action to '\(newAction.debugDescription)'")
    }
}
