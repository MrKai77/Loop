//
//  SettingsWindowManager.swift
//  Loop
//
//  Created by Kai Azim on 2024-05-28.
//

import Combine
import Defaults
import Luminare
import Scribe
import SwiftUI

@MainActor
final class SettingsWindowManager: ObservableObject {
    static let shared = SettingsWindowManager()
    private var controller: NSWindowController?
    private var previewActionTimerTask: Task<(), Error>?

    @Published var isPreviewingUserSelection: Bool = false {
        didSet { restartTimer() }
    }

    @Published private(set) var previewedParentAction: WindowAction? = nil
    @Published private(set) var previewedAction: WindowAction = .init(.noSelection) {
        didSet { radialMenuViewModel.setAction(to: previewedAction, parent: previewedParentAction) }
    }

    @Published var showRadialMenu: Bool = true
    @Published var showPreview: Bool = true

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
        let startingAction: WindowAction = .init(.noAction)

        self.radialMenuViewModel = .init(startingAction: startingAction, window: nil, previewMode: true)

        if let firstAction = RadialMenuAction.userConfiguredActions.first?.resolved {
            setPreviewedAction(to: firstAction)
        }
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

        Log.success("Settings window opened", category: .settingsWindowManager)
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

        Log.success("Settings window closed", category: .settingsWindowManager)
    }

    private func restartTimer() {
        stopTimer()
        startTimer()
    }

    private func startTimer() {
        previewActionTimerTask?.cancel()
        previewActionTimerTask = Task(priority: .utility) {
            try await Task.sleep(for: .seconds(1))

            while !Task.isCancelled {
                if controller?.window?.isKeyWindow == true {
                    setNextPreviewedAction()
                }

                try await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopTimer() {
        previewActionTimerTask?.cancel()
        previewActionTimerTask = nil
    }

    private func setNextPreviewedAction() {
        if isPreviewingUserSelection {
            guard let parent = previewedParentAction,
                  parent.direction == .cycle,
                  let cycle = parent.cycle,
                  let index = cycle.firstIndex(of: previewedAction)
            else {
                return
            }

            let nextIndex = (index + 1) % cycle.count
            setPreviewedAction(to: parent, cycleAction: cycle[nextIndex])
        } else {
            let radialMenuActions: [WindowAction] = RadialMenuAction.userConfiguredActions
                .compactMap(\.resolved)

            let nextAction = if let index = radialMenuActions.firstIndex(of: previewedParentAction ?? previewedAction) {
                radialMenuActions[(index + 1) % radialMenuActions.count]
            } else {
                radialMenuActions.first ?? .init(.noAction)
            }

            setPreviewedAction(to: nextAction)
        }
    }

    func setPreviewedAction(to newAction: WindowAction, cycleAction: WindowAction? = nil) {
        if newAction.direction == .cycle {
            previewedParentAction = newAction
            previewedAction = cycleAction ?? newAction.cycle?.first ?? .init(.noAction)
        } else {
            previewedParentAction = nil
            previewedAction = newAction
        }
    }
}
