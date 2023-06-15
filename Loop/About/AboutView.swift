//
//  AboutView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-29.
//

import SwiftUI

struct packageDescription {
    var name: String
    var url: URL
    var license: URL
}

struct AboutView: View {
    
    @Environment(\.openURL) private var openURL
    
    @State private var isShowingAcknowledgements = false
    @State private var isHoveringOverIcon = false
    
    let PACKAGES: [packageDescription] = [
        packageDescription(name: "Defaults", url: URL(string: "https://github.com/sindresorhus/Defaults")!, license: URL(string: "https://github.com/sindresorhus/Defaults/blob/main/license")!),
        packageDescription(name: "KeyboardShortcuts", url: URL(string: "https://github.com/sindresorhus/KeyboardShortcuts")!, license: URL(string: "https://github.com/sindresorhus/KeyboardShortcuts/blob/main/license")!),
        packageDescription(name: "Sparkle", url: URL(string: "https://sparkle-project.org")!, license: URL(string: "https://github.com/sparkle-project/Sparkle/blob/2.x/LICENSE")!),
    ]
    
    var iconAnimation: Animation {
        Animation.snappy
            .speed(0.5)
    }
    
    var body: some View {
        VStack {
            VStack(spacing: 5) {
                
                // When user puts their cursor at the center of the icon, the icon will spin
                ZStack {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 120, height: 120)
                        .rotationEffect(Angle.degrees(isHoveringOverIcon ? 360 : 0))
                        .animation(iconAnimation, value: isHoveringOverIcon)
                    
                    // This is what the user needs to hover over
                    Circle()
                        .foregroundColor(.clear)
                        .frame(width: 30, height: 30)
                        .onHover { hover in
                            self.isHoveringOverIcon = hover
                        }
                }
                
                Text("\(Bundle.main.appName)")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Version \(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
                    .font(.caption2)
                    .textSelection(.enabled)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("The elegant, mouse-oriented window manager")
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
            
            Button {
                self.isShowingAcknowledgements = true
            } label: {
                Text("Acknowledgements")
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .popover(isPresented: $isShowingAcknowledgements) {
                VStack {
                    ForEach(0..<PACKAGES.count, id: \.self) { i in
                        HStack {
                            Text(PACKAGES[i].name)
                            Spacer()
                            
                            Button(action: {
                                openURL(PACKAGES[i].url)
                            }, label: {
                                Image(systemName: "safari")
                            })
                            .help("link")
                            
                            Button(action: {
                                openURL(PACKAGES[i].license)
                            }, label: {
                                Image(systemName: "info.circle")
                            })
                            .help("license")
                        }
                        .frame(width: 180)
                        .buttonStyle(.link)
                        .tag(i)
                        .padding(.vertical, 2)
                    }
                }
                .padding(10)
            }
            
            Link(destination: URL(string: "https://github.com/MrKai77/Loop/blob/release/LICENSE")!) {
                Text("MIT License")
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
        .frame(width: 260, height: 380)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow).ignoresSafeArea())
    }
}
