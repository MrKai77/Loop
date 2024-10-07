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
    case keybindings

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
        case .keybindings: .init(localized: "Settings tab: Keybindings", defaultValue: "Keybindings")
        case .advanced: .init(localized: "Settings tab: Advanced", defaultValue: "Advanced")
        case .excludedApps: .init(localized: "Settings tab: Excluded Apps", defaultValue: "Excluded Apps")
        case .about: .init(localized: "Settings tab: About", defaultValue: "About")
        }
    }

    var icon: Image {
        switch self {
        case .icon: Image(._18PxSquareSparkle)
        case .accentColor: Image(._18PxPaintbrush)
        case .radialMenu: Image(.loop)
        case .preview: Image(._18PxSidebarRight2)
        case .behavior: Image(._18PxGear)
        case .keybindings: Image(._18PxCommand)
        case .advanced: Image(._18PxFaceNerdSmile)
        case .excludedApps: Image(._18PxWindowLock)
        case .about: Image(._18PxMsgSmile2)
        }
    }

    var showIndicator: Bool {
        switch self {
        case .about: AppDelegate.updater.updateState == .available
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
        case .keybindings: KeybindingsConfigurationView()
        case .advanced: AdvancedConfigurationView()
        case .excludedApps: ExcludedAppsConfigurationView()
        case .about: AboutConfigurationView()
        }
    }

    static let theming: [Tab] = [.icon, .accentColor, .radialMenu, .preview]
    static let settings: [Tab] = [.behavior, .keybindings]
    static let loop: [Tab] = [.advanced, .excludedApps, .about]
}

class LuminareManager {
    static var luminare: LuminareWindow?

    static func open() {
        if luminare == nil {
            LuminareConstants.tint = {
                AppDelegate.isActive ? Color.getLoopAccent(tone: .normal) : Color.systemGray
            }
            luminare = LuminareWindow(blurRadius: 20) {
                LuminareContentView()
            }
            luminare?.center()
        }

        luminare?.show()

        LuminareWindowModel.shared.startTimer()

        AppDelegate.isActive = true
        NSApp.setActivationPolicy(.regular)
    }

    static func fullyClose() {
        luminare?.close()
        luminare = nil

        LuminareWindowModel.shared.stopTimer()

        if !Defaults[.showDockIcon] {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

class LuminareWindowModel: ObservableObject {
    static let shared = LuminareWindowModel()
    private init() {}

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

    @Published var showRadialMenu: Bool = false
    @Published var showPreview: Bool = false
    @Published var showInspector: Bool = true {
        didSet {
            if showInspector {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }

    @Published var timer: AnyCancellable?
    @Published var previewedAction: WindowAction = .init(.topHalf)

    let themingTabs: [Tab] = Tab.theming
    let settingsTabs: [Tab] = Tab.settings
    let loopTabs: [Tab] = Tab.loop

    func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard AppDelegate.isActive, let self else { return }
                previewedAction.direction = previewedAction.direction.nextPreviewDirection
            }
    }

    func stopTimer() {
        timer?.cancel()
    }
}

struct LuminareContentView: View {
    @ObservedObject var model = LuminareWindowModel.shared

    var body: some View {
        LuminareDividedStack {
            LuminareSidebar {
                LuminareSidebarSection("Theming", selection: $model.currentTab, items: model.themingTabs)
                LuminareSidebarSection("Settings", selection: $model.currentTab, items: model.settingsTabs)
                LuminareSidebarSection("\(Bundle.main.appName)", selection: $model.currentTab, items: model.loopTabs)
            }
            .frame(width: 260)

            LuminarePane {
                HStack {
                    model.currentTab.iconView()

                    Text(model.currentTab.title)
                        .font(.title2)

                    Spacer()

                    Button {
                        model.showInspector.toggle()
                    } label: {
                        Image(model.showInspector ? ._18PxSidebarLeftHide : ._18PxSidebarLeft3)
                    }
                }
            } content: {
                model.currentTab.view()
                    .transition(.opacity.animation(.easeInOut(duration: 0.1)))
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
                .animation(LuminareConstants.animation, value: [model.showRadialMenu, model.showPreview])
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
    }
}
