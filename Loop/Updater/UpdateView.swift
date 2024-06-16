//
//  UpdateView.swift
//  Loop
//
//  Created by Kami on 15/06/2024.
//

import Luminare
import SwiftUI

struct UpdateView: View {
    let appState: AppState
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
                        AppDelegate.updater.dismissUpdateWindow(appState: appState)
                    }
                    .buttonStyle(LuminareButtonStyle())

                    Button(
                        action: {
                            if !isInstalling {
                                withAnimation {
                                    isInstalling.toggle()
                                }
                                AppDelegate.updater.downloadUpdate(appState: appState)
                            } else if appState.progressBar.1 == 1.0 {
                                // The update is complete, and we should restart the app
                                AppDelegate.updater.updateWindow?.close()
                                AppDelegate.relaunch()
                            }
                        },
                        label: {
                            if appState.progressBar.1 < 1.0 {
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
                                    .frame(width: CGFloat(appState.progressBar.1) * geo.size.width)
                                    .animation(.easeIn(duration: 1), value: appState.progressBar.1)
                            }
                            .allowsHitTesting(false)
                            .opacity(appState.progressBar.1 < 1.0 ? 1 : 0)
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
            Text(Bundle.main.appVersion)
            Image(systemName: "arrow.right")
            Text(appState.releases.first?.tagName ?? "Unknown")
        }
        .font(.title3)
        .blendMode(.overlay)
    }

    func changelogView() -> some View {
        ScrollView {
            VStack(alignment: .leading) {
                let splitLines = appState.changelogText  // Use dynamic content from AppState
                    .replacingOccurrences(of: "\r", with: "")
                    .components(separatedBy: "\n")

                ForEach(Array(splitLines.enumerated()), id: \.offset) { index, line in
                    if line.hasPrefix("#") {
                        if index > 0 {
                            Divider()
                        }

                        let line =
                        line
                            .replacingOccurrences(of: "#", with: "")
                            .trimmingCharacters(in: .whitespaces)

                        Text(LocalizedStringKey(line))
                            .font(.headline)
                            .padding(.bottom, 2)
                    } else if line.hasPrefix("-") {
                        let line =
                        line
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

// If we can make this look better, much appreciated.
// EDIT: Removed for now since I might have an idea...
//struct NoUpdateView: View {
//    @EnvironmentObject var appState: AppState
//
//    var body: some View {
//        VStack {
//            Spacer(minLength: 20)
//
//            Image(nsImage: NSApp.applicationIconImage)
//                .resizable()
//                .aspectRatio(contentMode: .fit)
//                .frame(width: 80, height: 80)
//                .padding(.top, 20)
//
//            Text("You're up-to-date!")
//                .font(.headline)
//                .padding(.vertical, 8)
//
//            Text("Current Version: \(Bundle.main.appVersion)")
//                .font(.subheadline)
//                .padding(.bottom, 20)
//
//            Button("Dismiss") {
//                Updater.updateWindow?.close()
//            }
//            .buttonStyle(LuminareButtonStyle())
//            .padding(.bottom, 20)
//
//            Spacer(minLength: 20)
//        }
//        .frame(width: 170, height: 200)  // Update the sizing here
//        /// This may not conform nicely... but... we'll see.
//        /// It's due to window sizing in the NewWindow.
//        .padding()
//    }
//}
