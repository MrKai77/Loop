//
//  LuminareManager.swift
//  Loop
//
//  Created by Kai Azim on 2024-05-28.
//

import Combine
import Defaults
import Luminare
import SwiftUI

extension String: @retroactive Identifiable {
    public var id: String { self }
}

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

    static let theming: [Tab] = [.icon, .accentColor, .radialMenu, .preview]
    static let settings: [Tab] = [.behavior, .keybinds]
    static let loop: [Tab] = [.advanced, .excludedApps, .about]
}

class LuminareManager: NSWindowController, ObservableObject {
    static let shared = LuminareManager()

    var luminare: LuminareWindow?
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

    private init() {
        let startingAction: WindowAction = .init(.topHalf)

        self.previewedAction = startingAction
        self.radialMenuViewModel = .init(startingAction: startingAction, window: nil, previewMode: true)

        super.init(window: nil)

        let window = LuminareWindow {
            LuminareContentView(model: self)
                .frame(height: 570) // Does not include titlebar height
        }

        self.window = window
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.orderFrontRegardless()

        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        do {
            try window?.setBackgroundBlur(radius: 20)
            window?.backgroundColor = .white.withAlphaComponent(0.001)
            window?.ignoresMouseEvents = false
        } catch {
            print(error)
        }

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

struct LuminareContentView: View {
    @ObservedObject var model: LuminareManager
    @ObservedObject private var accentColorController: AccentColorController = .shared
    @Environment(\.luminareAnimation) private var animation

    var body: some View {
        LuminareDividedStack {
            LuminareSidebar {
                LuminareSidebarSection("Theming", selection: $model.currentTab, items: Tab.theming)
                LuminareSidebarSection("Settings", selection: $model.currentTab, items: Tab.settings)
                LuminareSidebarSection("\(Bundle.main.appName)", selection: $model.currentTab, items: Tab.loop)
            }
            .frame(width: 260)

            LuminarePane {
                model.currentTab.view()
            } header: {
                HStack {
                    model.currentTab.decoratedImageView

                    Text(model.currentTab.title)
                        .font(.title2)

                    Spacer()

                    Button {
                        model.showInspector.toggle()
                    } label: {
                        Image(model.showInspector ? .sidebarLeftHide : .sidebarLeft3)
                    }
                }
            }
            .frame(width: 390)

            if model.showInspector {
                ZStack {
                    if model.showPreview {
                        LuminarePreviewView()
                    }

                    if model.showRadialMenu {
                        VStack {
                            RadialMenuView(viewModel: model.radialMenuViewModel)
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                }
                .animation(animation, value: [model.showRadialMenu, model.showPreview])
                .ignoresSafeArea()
                .frame(width: 520)
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                model.showPreview = true
                model.showRadialMenu = true
            }
        }
        .luminareTint(overridingWith: accentColorController.color1)
    }
}

// MARK: LuminareWindow.setBackgroundBlur(radius:)

extension NSWindow {
    func setBackgroundBlur(radius: Int) throws {
        guard let connection = SLSDefaultConnectionForThread() else {
            throw NSError(
                domain: "com.Luminare.NSWindow",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Error getting default connection"]
            )
        }

        let status = SLSSetWindowBackgroundBlurRadius(connection, windowNumber, radius)

        if status != noErr {
            throw NSError(
                domain: "com.Luminare.NSWindow",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Error setting blur radius: \(status)"]
            )
        }
    }
}

@_silgen_name("SLSDefaultConnectionForThread")
func SLSDefaultConnectionForThread() -> SLSConnectionID?

@_silgen_name("SLSSetWindowBackgroundBlurRadius") @discardableResult
func SLSSetWindowBackgroundBlurRadius(
    _ connection: SLSConnectionID,
    _ windowNum: NSInteger,
    _ radius: Int
) -> OSStatus
