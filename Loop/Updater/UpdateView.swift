//
//  UpdateView.swift
//  Loop
//
//  Created by Kami on 15/06/2024.
//

import Luminare
import SwiftUI

struct UpdateView: View {
    @ObservedObject var updater = AppDelegate.updater
    @State var isInstalling: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                theLoopTimesView()
                versionChangeView()
            }

            LuminareSection {
                changelogView()

                HStack(spacing: 2) {
                    Button("Remind me later") {
                        AppDelegate.updater.dismissWindow()
                    }
                    .buttonStyle(LuminareButtonStyle())

                    Button(
                        action: {
                            if !isInstalling {
                                withAnimation {
                                    isInstalling.toggle()
                                }
                                Task {
                                    await AppDelegate.updater.installUpdate()
                                }
                            } else if updater.progressBar.1 == 1.0 {
                                AppDelegate.updater.dismissWindow()
                                AppDelegate.relaunch()
                            }
                        },
                        label: {
                            if updater.progressBar.1 < 1.0 {
                                Text(isInstalling ? "Downloading & installing..." : "Install")
                            } else {
                                Text("Restart to complete")
                            }
                        }
                    )

                    .buttonStyle(LuminareButtonStyle())
                    .overlay {
                        if isInstalling {
                            GeometryReader { geo in
                                Rectangle()
                                    .foregroundStyle(.tertiary)
                                    .clipShape(.rect(cornerRadius: 4))
                                    .frame(width: CGFloat(updater.progressBar.1) * geo.size.width)
                                    .animation(.easeIn(duration: 1), value: updater.progressBar.1)
                            }
                            .allowsHitTesting(false)
                            .opacity(updater.progressBar.1 < 1.0 ? 1 : 0)
                        }
                    }
                }
                .frame(height: 42)
            }
        }
        .frame(width: 570, height: 480)
    }

    func theLoopTimesView() -> some View {
        ZStack {
            TheLoopTimes()
                .fill(
                    .shadow(.inner(color: .black.opacity(0.1), radius: 3))
                    .shadow(.inner(color: .black.opacity(0.3), radius: 5, y: 3))
                )
                .foregroundStyle(.white.opacity(0.7))
                .blendMode(.overlay)

            TheLoopTimes()
                .stroke(.white.opacity(0.1), lineWidth: 1)
                .blendMode(.luminosity)
        }
        .aspectRatio(883.88 / 135.53, contentMode: .fit)
        .frame(width: 450)
    }

    func versionChangeView() -> some View {
        HStack {
            Text(Bundle.main.appVersion ?? "Unknown")
            Image(systemName: "arrow.right")
            Text(updater.availableReleases.first?.tagName ?? "Unknown")
        }
        .font(.title3)
        .blendMode(.overlay)
    }

    func changelogView() -> some View {
        ScrollView {
            VStack(alignment: .leading) {
                let splitLines = updater.changelogText  // Use dynamic content from AppState
                    .replacingOccurrences(of: "\r", with: "")
                    .components(separatedBy: "\n")

                ForEach(Array(splitLines.enumerated()), id: \.offset) { index, line in
                    if line.hasPrefix("#") {
                        if index > 0 {
                            Divider()
                        }

                        let line = line
                            .replacingOccurrences(of: "#", with: "")
                            .trimmingCharacters(in: .whitespaces)

                        Text(LocalizedStringKey(line))
                            .font(.headline)
                            .padding(.bottom, 2)
                    } else if line.hasPrefix("-") {
                        let line = line
                            .replacingOccurrences(of: "-", with: "•")
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                        Text(LocalizedStringKey(line))
                            .padding(.leading, 6)
                        // Should most likely format it nicer :joy:
                            .padding(.vertical, 1)  // Added vertical padding for `-` sections
                    } else {
                        Text(LocalizedStringKey(line))
                    }
                }
            }
            .padding(12)
        }
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.05),
                    .init(color: .black, location: 0.9),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
