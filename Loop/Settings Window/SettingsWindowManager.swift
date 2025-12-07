//
//  SettingsWindowManager.swift
//  Loop
//
//  Created by Kai Azim on 2024-05-28.
//

import Combine
import Defaults
import Luminare
import OSLog
import SwiftUI

@MainActor
final class SettingsWindowManager: ObservableObject {
    static let shared = SettingsWindowManager()
    private let logger = Logger(category: "SettingsWindowManager")
    private var controller: NSWindowController?
    private var previewActionTimerTask: Task<(), Error>?

    @Published private(set) var previewedAction: WindowAction

    @Published var showRadialMenu: Bool = false
    @Published var showPreview: Bool = false

    @Published var currentTab: SettingsTab = .icon {
        didSet {
            if currentTab == .radialMenu {
                showRadialMenu = true
                showPreview = false
            } else if currentTab == .preview {
                showRadialMenu = false
                showPreview = true
            } else {
                showRadialMenu = true
                showPreview = true
            }
        }
    }

    @Published var showInspector: Bool = true {
        didSet {
            if showInspector {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }

    let radialMenuViewModel: RadialMenuViewModel

    var window: NSWindow? {
        controller?.window
    }

    private init() {
        let startingAction: WindowAction = .init(.topHalf)

        self.previewedAction = startingAction
        self.radialMenuViewModel = .init(startingAction: startingAction, window: nil, previewMode: true)
    }

    func show() {
        if controller == nil {
            let window = LuminareWindow {
                SettingsContentView(model: self)
                    .frame(height: 620)
            }

            SkyLightToolBelt.setBackgroundBlur(
                windowID: CGWindowID(window.windowNumber),
                radius: 20
            )

            window.backgroundColor = .white.withAlphaComponent(0.001)
            window.ignoresMouseEvents = false

            controller = NSWindowController(window: window)
        }

        startTimer()
        NSApp.setActivationPolicy(.regular)

        controller?.showWindow(self)
        window?.orderFrontRegardless()

        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        logger.log("Settings window opened")
    }

    func close() {
        if let controller {
            controller.close()
            self.controller = nil
        }

        stopTimer()

        if !Defaults[.showDockIcon] {
            NSApp.setActivationPolicy(.accessory)
        }

        logger.log("Settings window closed")
    }

    private func startTimer() {
        previewActionTimerTask?.cancel()
        previewActionTimerTask = Task(priority: .utility) {
            while true {
                try await Task.sleep(for: .seconds(1))

                if await controller?.window?.isKeyWindow == true, !Task.isCancelled {
                    await MainActor.run {
                        previewedAction.direction = previewedAction.direction.nextPreviewDirection
                        radialMenuViewModel.setAction(to: previewedAction)
                    }
                }
            }
        }
    }

    private func stopTimer() {
        previewActionTimerTask?.cancel()
        previewActionTimerTask = nil
    }
}
