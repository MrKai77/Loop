//
//  RadialMenuController.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import Defaults
import Scribe
import SwiftUI

@Loggable
@MainActor
final class RadialMenuController: WindowActionIndicator {
    private let windowSize: CGFloat = 100 + 80

    private var viewModel: RadialMenuViewModel = .init(isSettingsPreview: false)
    private var controller: NSWindowController?
    private var closeTask: Task<(), Never>?
    private var displayedScreen: NSScreen?

    func open(context: ResizeContext) {
        defer { viewModel.updateContext(with: context) }

        closeTask?.cancel()
        closeTask = nil

        if let window = controller?.window {
            updatePositionIfNeeded(at: NSEvent.mouseLocation)
            viewModel.setIsShown(true, animationDuration: 0.1)
            window.orderFrontRegardless()
            return
        }

        let mouseX: CGFloat = context.initialMousePosition.x
        let mouseY: CGFloat = context.initialMousePosition.y

        let panel = ActivePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        controller = .init(window: panel)

        panel.ignoresMouseEvents = true
        panel.collectionBehavior = .canJoinAllSpaces
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.level = .screenSaver
        panel.contentView = NSHostingView(rootView: RadialMenuView(viewModel: viewModel))

        // Position the panel
        if Defaults[.lockRadialMenuToCenter], let screen = NSScreen.main {
            // Position at the center of the screen
            let screenFrame = screen.frame
            panel.setFrameOrigin(
                NSPoint(
                    x: screenFrame.midX - windowSize / 2,
                    y: screenFrame.midY - windowSize / 2
                )
            )
            displayedScreen = screen
        } else {
            // Position at the mouse cursor
            setPanelOrigin(panel, at: CGPoint(x: mouseX, y: mouseY))
            displayedScreen = NSScreen.screenWithMouse
        }

        panel.orderFrontRegardless()

        log.ui("Initialized controller")
    }

    /// Moves the radial menu to the cursor only when it has entered a different
    /// display. Keeping the existing position within a display preserves Loop's
    /// normal radial-menu interaction, while the opt-in setting makes the menu
    /// usable across a multi-display desktop.
    func updatePositionIfNeeded(at mousePosition: CGPoint) {
        guard
            Defaults[.moveRadialMenuAcrossScreens],
            !Defaults[.lockRadialMenuToCenter],
            let panel = controller?.window,
            let currentScreen = NSScreen.screenWithMouse
        else {
            return
        }

        let previousScreen = displayedScreen ?? panel.screen
        guard let previousScreen, !previousScreen.isSameScreen(currentScreen) else {
            return
        }

        setPanelOrigin(panel, at: mousePosition)
        displayedScreen = currentScreen
    }

    func close() {
        guard controller != nil else { return }
        closeTask?.cancel()
        closeTask = Task { [weak self] in
            guard let self else { return }
            viewModel.setIsShown(false, animationDuration: 0.15)
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }
            controller?.window?.orderOut(nil)
            controller?.close()
            controller = nil
            displayedScreen = nil
            closeTask = nil
            log.ui("Controller closed")
        }
    }

    /// Centers the fixed-size radial panel on a global AppKit mouse position.
    private func setPanelOrigin(_ panel: NSWindow, at mousePosition: CGPoint) {
        panel.setFrameOrigin(
            NSPoint(
                x: mousePosition.x - windowSize / 2,
                y: mousePosition.y - windowSize / 2
            )
        )
    }
}
