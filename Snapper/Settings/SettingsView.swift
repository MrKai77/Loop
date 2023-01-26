//
//  SettingsView.swift
//  Snapper
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI

struct SettingsView: View {
    
    @State var currentWindowHeight = 1
    
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
                    .onAppear {
                        self.currentWindowHeight = 410
                    }
                
                RadialMenuSettingsView()
                    .tabItem {
                        Image(systemName: "circle.dashed")
                        Text("Radial Menu")
                    }
                    .onAppear {
                        self.currentWindowHeight = 377
                    }
                
                PreviewSettingsView()
                    .tabItem {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Preview")
                    }
                    .onAppear {
                        self.currentWindowHeight = 388
                    }
                
                KeybindingSettingsView()
                    .tabItem {
                        Image(systemName: "keyboard")
                        Text("Keybindings")
                    }
                    .onAppear {
                        self.currentWindowHeight = 454
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
            self.window?.orderFrontRegardless()
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
