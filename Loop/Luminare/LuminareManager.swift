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

class LuminareManager: LuminareCoordinator, ObservableObject {
    static let shared = LuminareManager()

    var luminare: LuminareWindow?

    @Published var timer: AnyCancellable?
    @Published var previewedAction: WindowAction = .init(.topHalf)

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

    var body: some View {
        LuminareContentView(model: self)
            .frame(height: 570) // Does not include titlebar height
    }

    func open() {
        showWindow()

        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        do {
            try luminare?.setBackgroundBlur(radius: 20)
            luminare?.backgroundColor = .white.withAlphaComponent(0.001)
            luminare?.ignoresMouseEvents = false
        } catch {
            print(error)
        }

        startTimer()
        NSApp.setActivationPolicy(.regular)
    }

    func close() {
        closeWindow()
        stopTimer()

        if !Defaults[.showDockIcon] {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard self?.luminare?.isKeyWindow == true, let self else { return }
                previewedAction.direction = previewedAction.direction.nextPreviewDirection
            }
    }

    func stopTimer() {
        timer?.cancel()
    }
}

struct LuminareContentView: View {
    @ObservedObject var model: LuminareManager
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
                            RadialMenuView(previewMode: true, startingAction: model.previewedAction)
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
        .luminareTint(overridingWith: .getLoopAccent(tone: .normal))
    }
}

// MARK: LuminareWindow.setBackgroundBlur(radius:)

extension LuminareWindow {
    func setBackgroundBlur(radius: Int) throws {
        guard let connection = CGSDefaultConnectionForThread() else {
            throw NSError(
                domain: "com.Luminare.NSWindow",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Error getting default connection"]
            )
        }

        let status = CGSSetWindowBackgroundBlurRadius(connection, windowNumber, radius)

        if status != noErr {
            throw NSError(
                domain: "com.Luminare.NSWindow",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Error setting blur radius: \(status)"]
            )
        }
    }
}

@_silgen_name("CGSDefaultConnectionForThread")
func CGSDefaultConnectionForThread() -> CGSConnectionID?

@_silgen_name("CGSSetWindowBackgroundBlurRadius") @discardableResult
func CGSSetWindowBackgroundBlurRadius(
    _ connection: CGSConnectionID,
    _ windowNum: NSInteger,
    _ radius: Int
) -> OSStatus
