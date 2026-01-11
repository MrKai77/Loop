//
//  RadialMenuController.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import Defaults
import Scribe
import SwiftUI

final class RadialMenuController {
    private var controller: NSWindowController?
    private var viewModel: RadialMenuViewModel?

    func open(
        position: CGPoint,
        window: Window?,
        startingAction: WindowAction
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
        let windowSize: CGFloat = 100 + 80

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
    }

    func close() {
        guard let windowController = controller else { return }
        controller = nil

        Task { @MainActor in
            viewModel?.setIsShown(false, animationDuration: 0.15)
            try? await Task.sleep(for: .seconds(0.15))
            windowController.close()
        }
    }

    func setWindow(to newWindow: Window) {
        viewModel?.setWindow(to: newWindow)
    }

    func setAction(to newAction: WindowAction, parent: WindowAction?) {
        viewModel?.setAction(to: newAction, parent: parent)

        Log.ui("Set action to '\(newAction.description)'", category: .radialMenuController)
    }
}
