//
//  AboutView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-29.
//

import SwiftUI

struct AboutView: View {
    
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack {
            VStack(spacing: 5) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 120, height: 120)
                
                Text("\(Bundle.main.appName)")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Version \(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
                    .font(.caption2)
                    .textSelection(.enabled)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("The missing window manager from the stock MacOS experience")
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Button {
                openURL(URL(string: "https://github.com/MrKai77/Loop")!)
            } label: {
                Text("Github")
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            
            #if DEBUG
            Button {
                let alert = NSAlert()
                alert.messageText = "\(Bundle.main.appName)"
                alert.informativeText = "You triggered an alert!"
                alert.runModal()
            } label: {
                Text("DEBUG: TRIGGER ALERT")
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            #endif
            
            Link(destination: URL(string: "https://github.com/MrKai77/Loop/blob/main/LICENSE")!) {
                Text("Apache License 2.0")
                    .underline()
                    .font(.caption)
                    .textSelection(.disabled)
                    .foregroundColor(.secondary)
            }
            
            Text(Bundle.main.copyright)
                .textSelection(.disabled)
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(20)
        .frame(width: 260, height: 360)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow).ignoresSafeArea())
    }
}
