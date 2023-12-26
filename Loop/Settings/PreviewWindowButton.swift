//
//  PreviewWindowButton.swift
//  Loop
//
//  Created by Kai Azim on 2023-12-25.
//

import SwiftUI

struct PreviewWindowButton: NSViewRepresentable {

    @Binding var keybind: Keybind

    init(_ keybind: Binding<Keybind>) {
        self._keybind = keybind
    }

    func makeNSView(context: NSViewRepresentableContext<Self>) -> NSButton {

        let button = NSButton(
            title: "Show",
            target: context.coordinator,
            action: #selector(Coordinator.buttonClicked)
        )

        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.defaultHigh, for: .vertical)
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.sendAction(on: [.leftMouseDown, .leftMouseUp, .leftMouseDragged])

        // Having this tracking area ensures that the preview window is closed even
        // when the cursor is outside the button during button release.
        let trackingArea = NSTrackingArea(
            rect: button.bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: context.coordinator,
            userInfo: nil
        )
        button.addTrackingArea(trackingArea)

        context.coordinator.parent = self

        return button
    }

    func updateNSView(_ nsView: NSButton, context: NSViewRepresentableContext<Self>) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator _: Coordinator) {
      nsView.trackingAreas.forEach { nsView.removeTrackingArea($0) }
    }

    class Coordinator: NSResponder {
        var parent: PreviewWindowButton

        let previewController = PreviewController()

        init(_ parent: PreviewWindowButton) {
            self.parent = parent
            super.init()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc func buttonClicked() {
            if NSApp.currentEvent?.type == .leftMouseUp {
                self.previewController.close()
            } else {
                guard let screen = NSScreen.screenWithMouse else { return }
                self.previewController.open(screen: screen, startingAction: self.parent.keybind)
            }
        }

        override func mouseExited(with _: NSEvent) {
            self.previewController.close()
        }
    }
}
