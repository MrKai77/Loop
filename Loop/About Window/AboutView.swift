//
//  AboutView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-29.
//

import SwiftUI

struct PackageDescription {
    var name: String
    var url: URL
    var license: URL
}

struct AboutView: View {
    @Environment(\.openURL) private var openURL

    @State private var isShowingAcknowledgements = false

    let packages: [PackageDescription] = [
        PackageDescription(
            name: "Defaults",
            url: URL(
                string: "https://github.com/sindresorhus/Defaults"
            )!,
            license: URL(string: "https://github.com/sindresorhus/Defaults/blob/main/license")!
        ),
        PackageDescription(
            name: "MenuBarExtraAccess",
            url: URL(
                string: "https://github.com/orchetect/MenuBarExtraAccess"
            )!,
            license: URL(string: "https://github.com/orchetect/MenuBarExtraAccess/blob/main/LICENSE")!
        ),
        PackageDescription(
            name: "Settings",
            url: URL(
                string: "https://github.com/sindresorhus/Settings"
            )!,
            license: URL(
                string: "https://github.com/sindresorhus/Settings/blob/main/license"
            )!
        ),
        PackageDescription(
            name: "Sparkle",
            url: URL(
                string: "https://sparkle-project.org"
            )!,
            license: URL(
                string: "https://github.com/sparkle-project/Sparkle/blob/2.x/LICENSE"
            )!
        )
    ]

    var body: some View {
        VStack {
            VStack(spacing: 5) {

                Image(nsImage: NSImage(named: IconManager.currentAppIcon.name)!)
                    .resizable()
                    .frame(width: 120, height: 120)

                Text("\(Bundle.main.appName)")
                    .font(.title)
                    .fontWeight(.bold)

                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(
                        "Version \(Bundle.main.appVersion) (\(Bundle.main.appBuild))",
                        forType: NSPasteboard.PasteboardType.string
                    )
                },
                       label: {
                    // swiftlint:disable:next line_length
                    Text("Version \(Bundle.main.appVersion) (\(Bundle.main.appBuild)) \(Image(systemName: "doc.on.clipboard"))")
                        .font(.caption2)
                        .textSelection(.enabled)
                        .foregroundColor(.secondary)
                })
                .buttonStyle(.plain)
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
                    ForEach(0..<packages.count, id: \.self) { idx in
                        HStack {
                            Text(packages[idx].name)
                            Spacer()

                            Button(action: {
                                openURL(packages[idx].url)
                            }, label: {
                                Image(systemName: "safari")
                            })
                            .help("link")

                            Button(action: {
                                openURL(packages[idx].license)
                            }, label: {
                                Image(systemName: "scroll")
                            })
                            .help("license")
                        }
                        .frame(width: 180)
                        .buttonStyle(.link)
                        .tag(idx)
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
