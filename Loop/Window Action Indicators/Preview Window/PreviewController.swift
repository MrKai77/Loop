//
//  PreviewController.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import Defaults
import Scribe
import SwiftUI

@Loggable
@MainActor
final class PreviewController: WindowActionIndicator {
    private let viewModel: PreviewViewModel = .init(isSettingsPreview: false)
    private var controller: NSWindowController?

    func open(context: ResizeContext) {
        guard let screen = context.screen else {
            log.error("Screen not defined in context")
            return
        }

        defer { viewModel.updateContext(with: context) }

        if let windowController = controller {
            // Move panel to new screen if screen changed
            if windowController.window?.screen != screen {
                windowController.window?.setFrame(screen.frame, display: true)
            }
            windowController.window?.orderFrontRegardless()
            return
        }

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
        panel.level = NSWindow.Level(NSWindow.Level.screenSaver.rawValue - 1)
        panel.contentView = NSHostingView(rootView: PreviewView(viewModel: viewModel))
        panel.setFrame(screen.frame, display: true)

        panel.orderFrontRegardless()

        log.ui("Initialized controller")
    }

    func close() {
        guard let windowController = controller else { return }
        controller = nil

        Task {
            viewModel.setIsShown(false)
            try? await Task.sleep(for: .seconds(0.4))
            windowController.window?.orderOut(nil)
            windowController.close()

            log.ui("Controller closed")
        }
    }
}
