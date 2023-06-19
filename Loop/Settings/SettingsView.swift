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
    
    var body: some View {
        TabView(selection: $currentSettingsTab) {
            GeneralSettingsView()
                .tag(1)
                .tabItem {
                    Image(systemName: "gear")
                    Text("General")
                }
            
            RadialMenuSettingsView()
                .tag(2)
                .tabItem {
                    Image("RadialMenuImage")
                    Text("Radial Menu")
                }
            
            PreviewSettingsView()
                .tag(3)
                .tabItem {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Preview")
                }
            
            KeybindingSettingsView()
                .tag(4)
                .tabItem {
                    Image(systemName: "keyboard")
                    Text("Keybindings")
                }
            
            MoreSettingsView(updater: updaterController.updater)
                .tag(5)
                .tabItem {
                    Image(systemName: "ellipsis.circle")
                    Text("More")
                }
        }
        .frame(width: 450)
    }
}
