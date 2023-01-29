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
        ZStack {
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            TabView(selection: self.$currentSettingsTab) {
                GeneralSettingsView()
                    .tag(1)
                    .tabItem {
                        Image(systemName: "gear")
                        Text("General")
                    }
                    .onAppear {
                        self.currentWindowHeight = 410
                    }
                
                RadialMenuSettingsView()
                    .tag(2)
                    .tabItem {
                        Image("RadialMenuImage")
                        Text("Radial Menu")
                    }
                    .onAppear {
                        self.currentWindowHeight = 377
                    }
                
                PreviewSettingsView()
                    .tag(3)
                    .tabItem {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Preview")
                    }
                    .onAppear {
                        self.currentWindowHeight = 388
                    }
                
                KeybindingSettingsView()
                    .tag(4)
                    .tabItem {
                        Image(systemName: "keyboard")
                        Text("Keybindings")
                    }
                    .onAppear {
                        self.currentWindowHeight = 663
                    }
                
                MoreSettingsView(updater: updaterController.updater)
                    .tag(5)
                    .tabItem {
                        Image(systemName: "ellipsis.circle")
                        Text("More")
                    }
                    .onAppear {
                        self.currentWindowHeight = 116
                    }
            }
        }
        .frame(width: 420, height: CGFloat(self.currentWindowHeight))
        .background(setSettingsWindowProperties())
    }
}

struct setSettingsWindowProperties: NSViewRepresentable {
    @State var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window
            self.window?.titlebarAppearsTransparent = true
            self.window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
            self.window?.standardWindowButton(.zoomButton)?.isHidden = true
            self.window?.isMovableByWindowBackground = true
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
