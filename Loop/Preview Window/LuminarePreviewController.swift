//
//  LuminarePreviewController.swift
//  Loop
//
//  Created by Kai Azim on 2024-05-27.
//

import SwiftUI
import Combine
import Defaults

class LuminarePreviewController {
    var controller: NSWindowController?
    var currentAction: WindowAction?
    var nextDirectionTimer: Timer?

    func openPreview() {
        if let windowController = controller {
            windowController.window?.close()
        }

        let bounds = AppDelegate.luminare.previewBounds

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true,
            screen: NSApp.keyWindow?.screen
        )

        panel.backgroundColor = .clear
        panel.contentView = NSHostingView(rootView: PreviewView(previewMode: true))
        panel.alphaValue = 0
        panel.identifier = .init("Preview")
        panel.setFrame(bounds ?? .zero, display: false)
        panel.orderFrontRegardless()

        controller = .init(window: panel)
        AppDelegate.luminare.windowController?.window?.addChildWindow(panel, ordered: .above)

        setPreviewAction(to: .init(.topHalf))

        nextDirectionTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(self.nextAction),
            userInfo: nil,
            repeats: true
        )
    }

    @objc func nextAction() {
        if controller?.window?.isVisible ?? false {
            setPreviewAction(to: .init(currentAction?.direction.nextPreviewDirection ?? .topHalf))
        } else {
            nextDirectionTimer?.invalidate()
            nextDirectionTimer = nil
        }
    }

    private func setPreviewAction(to action: WindowAction) {
        guard
            let windowController = controller,
            !action.direction.willChangeScreen,
            action.direction != .cycle
        else {
            return
        }

        var bounds = AppDelegate.luminare.previewBounds ?? .zero
        let originalOrigin = bounds.origin
        bounds.origin = .zero

        var targetWindowFrame = action.getFrame(window: nil, bounds: bounds)
            .flipY(maxY: bounds.maxY)

        targetWindowFrame.origin.x += originalOrigin.x
        targetWindowFrame.origin.y += originalOrigin.y

        if let animation = Defaults[.animationConfiguration].previewTimingFunction {
            NSAnimationContext.runAnimationGroup { context in
                context.timingFunction = animation
                windowController.window?.animator().setFrame(targetWindowFrame, display: true)
            }
        } else {
            windowController.window?.setFrame(targetWindowFrame, display: true)
        }

        currentAction = action
    }
}
