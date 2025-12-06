//
//  LuminareManager.swift
//  Loop
//
//  Created by Kai Azim on 2024-05-28.
//

import Combine
import Defaults
import Luminare
import OSLog
import SwiftUI

final class LuminareManager: NSWindowController, ObservableObject {
    static let shared = LuminareManager()
    private let logger = Logger(category: "LuminareManager")

    var luminare: LuminareWindow?
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

    private init() {
        let startingAction: WindowAction = .init(.topHalf)

        self.previewedAction = startingAction
        self.radialMenuViewModel = .init(startingAction: startingAction, window: nil, previewMode: true)

        super.init(window: nil)

        let window = LuminareWindow {
            LuminareContentView(model: self)
                .frame(height: 620)
        }

        self.window = window
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)

        guard let window else { return }

        window.orderFrontRegardless()

        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        SkyLightToolBelt.setBackgroundBlur(
            windowID: CGWindowID(window.windowNumber),
            radius: 20
        )

        window.backgroundColor = .white.withAlphaComponent(0.001)
        window.ignoresMouseEvents = false

        startTimer()
        NSApp.setActivationPolicy(.regular)
    }

    override func close() {
        super.close()

        stopTimer()

        if !Defaults[.showDockIcon] {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func startTimer() {
        previewActionTimerTask?.cancel()
        previewActionTimerTask = Task(priority: .utility) {
            while true {
                try await Task.sleep(for: .seconds(1))

                if window?.isKeyWindow == true, !Task.isCancelled {
                    await MainActor.run {
                        previewedAction.direction = previewedAction.direction.nextPreviewDirection
                        radialMenuViewModel.setAction(to: previewedAction)
                    }
                }
            }
        }
    }

    func stopTimer() {
        previewActionTimerTask?.cancel()
        previewActionTimerTask = nil
    }
}
