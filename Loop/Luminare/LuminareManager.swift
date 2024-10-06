//
//  LuminareManager.swift
//  Loop
//
//  Created by Kai Azim on 2024-05-28.
//

import Defaults
import Luminare
import SwiftUI
import Combine

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
        case .icon: return "Icon"
        case .accentColor: return "Accent Color"
        case .radialMenu: return "Radial Menu"
        case .preview: return "Preview"
        case .behavior: return "Behavior"
        case .keybindings: return "Keybindings"
        case .advanced: return "Advanced"
        case .excludedApps: return "Excluded Apps"
        case .about: return "About"
        }
    }

    var icon: Image {
        switch self {
        case .icon: return Image(._18PxSquareSparkle)
        case .accentColor: return Image(._18PxPaintbrush)
        case .radialMenu: return Image(.loop)
        case .preview: return Image(._18PxSidebarRight2)
        case .behavior: return Image(._18PxGear)
        case .keybindings: return Image(._18PxCommand)
        case .advanced: return Image(._18PxFaceNerdSmile)
        case .excludedApps: return Image(._18PxWindowLock)
        case .about: return Image(._18PxMsgSmile2)
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
            luminare = LuminareWindow(blurRadius: 20)  {
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
                guard AppDelegate.isActive, let self = self else { return }
                self.previewedAction.direction = self.previewedAction.direction.nextPreviewDirection
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
