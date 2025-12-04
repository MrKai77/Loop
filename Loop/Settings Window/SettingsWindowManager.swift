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

enum Tab: LuminareTabItem, CaseIterable {
    var id: String { title }

    case icon
    case accentColor
    case radialMenu
    case preview

    case behavior
    case keybinds

    case advanced
    case excludedApps
    case about

    var title: String {
        switch self {
        case .icon: .init(localized: "Settings tab: Icon", defaultValue: "Icon")
        case .accentColor: .init(localized: "Settings tab: Accent Color", defaultValue: "Accent Color")
        case .radialMenu: .init(localized: "Settings tab: Radial Menu", defaultValue: "Radial Menu")
        case .preview: .init(localized: "Settings tab: Preview", defaultValue: "Preview")
        case .behavior: .init(localized: "Settings tab: Behavior", defaultValue: "Behavior")
        case .keybinds: .init(localized: "Settings tab: Keybindings", defaultValue: "Keybinds")
        case .advanced: .init(localized: "Settings tab: Advanced", defaultValue: "Advanced")
        case .excludedApps: .init(localized: "Settings tab: Excluded Apps", defaultValue: "Excluded Apps")
        case .about: .init(localized: "Settings tab: About", defaultValue: "About")
        }
    }

    var image: Image {
        switch self {
        case .icon: Image(.squareSparkle)
        case .accentColor: Image(.paintbrush)
        case .radialMenu: Image(.loop)
        case .preview: Image(.sidebarRight2)
        case .behavior: Image(.gear)
        case .keybinds: Image(.command)
        case .advanced: Image(.faceNerdSmile)
        case .excludedApps: Image(.windowLock)
        case .about: Image(.msgSmile2)
        }
    }

    var showIndicator: Bool {
        switch self {
        case .about: Updater.shared.updateState == .available
        default: false
        }
    }

    @ViewBuilder func view() -> some View {
        switch self {
        case .icon: IconConfigurationView()
        case .accentColor: AccentColorConfigurationView()
        case .radialMenu: RadialMenuConfigurationView()
        case .preview: PreviewConfigurationView()
        case .behavior: BehaviorConfigurationView()
        case .keybinds: KeybindsConfigurationView()
        case .advanced: AdvancedConfigurationView()
        case .excludedApps: ExcludedAppsConfigurationView()
        case .about: AboutConfigurationView()
        }
    }

    static let themingTabs: [Tab] = [.icon, .accentColor, .radialMenu, .preview]
    static let settingsTabs: [Tab] = [.behavior, .keybinds]
    static let loopTabs: [Tab] = [.advanced, .excludedApps, .about]
}

final class SettingsWindowManager: ObservableObject {
    static let shared = SettingsWindowManager()
    private let logger = Logger(category: "SettingsWindowManager")
    private var controller: NSWindowController?
    private var previewActionTimerTask: Task<(), Error>?

    @Published private(set) var previewedAction: WindowAction

    @Published var showRadialMenu: Bool = false
    @Published var showPreview: Bool = false

    @Published var currentTab: Tab = .icon {
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
        if let controller, let window = controller.window {
            window.orderFrontRegardless()
        } else {
            let window = LuminareWindow {
                LuminareContentView(model: self)
                    .frame(height: 620)
            }

            controller = NSWindowController(window: window)

            SkyLightToolBelt.setBackgroundBlur(
                windowID: CGWindowID(window.windowNumber),
                radius: 20
            )

            window.backgroundColor = .white.withAlphaComponent(0.001)
            window.ignoresMouseEvents = false
            window.orderFrontRegardless()
        }

        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        startTimer()
        NSApp.setActivationPolicy(.regular)

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
