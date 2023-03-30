//
//  SettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Sparkle

struct SettingsView: View {
    
    private let updaterController: SPUStandardUpdaterController
        
    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    
    @State var currentSettingsTab = 1
    @State var currentWindowHeight = 1
    
    var body: some View {
        TabView(selection: $currentSettingsTab) {
            GeneralSettingsView()
                .tag(1)
                .tabItem {
                    Image(systemName: "gear")
                    Text("General")
                }
                .onAppear {
                    currentWindowHeight = 483
                }
            
            RadialMenuSettingsView()
                .tag(2)
                .tabItem {
                    Image("RadialMenuImage")
                    Text("Radial Menu")
                }
                .onAppear {
                    currentWindowHeight = 377
                }
            
            PreviewSettingsView()
                .tag(3)
                .tabItem {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Preview")
                }
                .onAppear {
                    currentWindowHeight = 388
                }
            
            KeybindingSettingsView()
                .tag(4)
                .tabItem {
                    Image(systemName: "keyboard")
                    Text("Keybindings")
                }
                .onAppear {
                    currentWindowHeight = 663
                }
            
            MoreSettingsView(updater: updaterController.updater)
                .tag(5)
                .tabItem {
                    Image(systemName: "ellipsis.circle")
                    Text("More")
                }
                .onAppear {
                    currentWindowHeight = 116
                }
        }
        .frame(width: 420, height: CGFloat(currentWindowHeight))
    }
}
