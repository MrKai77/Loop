//
//  SettingsView.swift
//  Snapper
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        ZStack {
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            TabView {
                GeneralSettingsView()
                    .tabItem {
                        Image(systemName: "gear")
                        Text("General")
                    }
                KeybindingSettingsView()
                    .tabItem {
                        Image(systemName: "keyboard")
                        Text("Keybindings")
                    }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
