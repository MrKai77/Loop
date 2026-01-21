//
//  SettingsContentView.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-18.
//

import Defaults
import Luminare
import SwiftUI

struct SettingsContentView: View {
    @ObservedObject var model: SettingsWindowManager
    @ObservedObject private var accentColorController: AccentColorController = .shared

    @Environment(\.luminareAnimation) private var animation
    @Environment(\.luminareTitleBarHeight) private var titleBarHeight
    @Default(.enableRadialMenuCustomization) var enableRadialMenuCustomization

    private var showRadialMenuGuide: Bool {
        enableRadialMenuCustomization && model.showRadialMenu && model.currentTab == .radialMenu
    }

    var body: some View {
        LuminareDividedStack {
            LuminareSidebar {
                LuminareSidebarSection("Theming", selection: $model.currentTab, items: SettingsTab.themingTabs)
                LuminareSidebarSection("Settings", selection: $model.currentTab, items: SettingsTab.settingsTabs)
                LuminareSidebarSection("\(Bundle.main.appName)", selection: $model.currentTab, items: SettingsTab.loopTabs)
            }
            .frame(width: 240)
            .padding(.top, titleBarHeight)
            .luminareBackground()

            LuminarePane {
                model.currentTab.view()
            } header: {
                HStack {
                    model.currentTab.icon

                    Text(model.currentTab.title)
                        .font(.title2)

                    Spacer()

                    Button {
                        model.showInspector.toggle()
                    } label: {
                        Image(systemName: "sidebar.right")
                            .animation(animation, value: model.showInspector)
                    }
                    .luminareContentSize(aspectRatio: 1, contentMode: .fit, hasFixedHeight: true)
                }
                .drawingGroup()
            }
            .frame(width: 390)

            if model.showInspector {
                // We use an overlay instead of a ZStack so the inspector’s contents
                // don’t influence the layout of the surrounding views (mainly as a precaution)
                Color.clear.overlay {
                    if model.showPreview || showRadialMenuGuide {
                        PreviewView(viewModel: model.previewViewModel)
                            .onGeometryChange(for: CGSize.self, of: \.size) {
                                model.setPreviewBounds(CGRect(origin: .zero, size: $0))
                            }
                    }

                    if model.showRadialMenu {
                        RadialMenuView(viewModel: model.radialMenuViewModel)
                            .allowsHitTesting(false)
                    }

                    if showRadialMenuGuide {
                        RadialMenuActionsGuide()
                    }
                }
                .animation(animation, value: [model.showRadialMenu, model.showPreview])
                .padding(12)
                .frame(width: 520)
            }
        }
        .luminareTint(overridingWith: accentColorController.color1)
        .ignoresSafeArea()
        .environmentObject(model)
    }
}
