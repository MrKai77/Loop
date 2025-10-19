//
//  LuminareContentView.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-18.
//

import Luminare
import SwiftUI

struct LuminareContentView: View {
    @ObservedObject var model: LuminareManager
    @ObservedObject private var accentColorController: AccentColorController = .shared

    @Environment(\.luminareAnimation) private var animation
    @Environment(\.luminareTitleBarHeight) private var titleBarHeight

    var body: some View {
        LuminareDividedStack {
            LuminareSidebar {
                LuminareSidebarSection("Theming", selection: $model.currentTab, items: Tab.themingTabs)
                LuminareSidebarSection("Settings", selection: $model.currentTab, items: Tab.settingsTabs)
                LuminareSidebarSection("\(Bundle.main.appName)", selection: $model.currentTab, items: Tab.loopTabs)
            }
            .frame(width: 260)
            .padding(.top, titleBarHeight)
            .luminareBackground()

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
        .ignoresSafeArea()
    }
}
