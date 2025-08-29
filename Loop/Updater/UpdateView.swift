//
//  UpdateView.swift
//  Loop
//
//  Created by Kami on 15/06/2024.
//

import Luminare
import SwiftUI

struct UpdateView: View {
    @Environment(\.luminareTintColor) var tintColor
    @Environment(\.luminareAnimation) var luminareAnimation
    @Environment(\.colorScheme) var colorScheme

    @ObservedObject var updater = Updater.shared
    @State var isInstalling: Bool = false
    @State var readyToRestart: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                theLoopTimesView()
                versionChangeView()
            }
            .padding([.top, .horizontal], 12)
            .padding(.bottom, 10)

            changelogView()
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            HStack {
                Button("Remind me later") {
                    Updater.shared.dismissWindow()
                }
                .disabled(isInstalling || readyToRestart)

                Button {
                    if readyToRestart {
                        AppDelegate.relaunch()
                    }

                    withAnimation(luminareAnimation) {
                        isInstalling = true
                    }
                    Task {
                        await Updater.shared.installUpdate()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            withAnimation(luminareAnimation) {
                                isInstalling = false
                            }
                            withAnimation(luminareAnimation) {
                                readyToRestart = true
                            }
                        }
                    }
                } label: {
                    ZStack {
                        if isInstalling {
                            Capsule()
                                .frame(maxWidth: .infinity)
                                .frame(height: 5)
                                .foregroundStyle(.quinary)
                                .overlay {
                                    GeometryReader { geo in
                                        Capsule()
                                            .foregroundStyle(tintColor)
                                            .frame(width: CGFloat(updater.progressBar) * geo.size.width)
                                            .animation(.smooth(duration: 0.8), value: updater.progressBar)
                                            .shadow(color: tintColor.opacity(0.1), radius: 12)
                                            .shadow(color: tintColor.opacity(0.4), radius: 6)
                                            .shadow(color: tintColor, radius: 1)
                                    }
                                }
                                .padding(.horizontal, 4)
                        }

                        let tenSpaces = "          " // This helps with alignment for the animation once the update finishes
                        Text(isInstalling ? tenSpaces : readyToRestart ? NSLocalizedString("Restart to complete", comment: "") : NSLocalizedString("Install", comment: ""))
                            .contentTransition(.numericText())
                            .opacity(isInstalling ? 0 : 1)
                    }
                }
                .allowsHitTesting(!isInstalling)
            }
            .luminareAspectRatio(contentMode: .fill)
            .buttonStyle(.luminareCompact)
            .padding(12)
            .background(VisualEffectView(material: .menu, blendingMode: .behindWindow))
            .overlay {
                VStack {
                    Divider()
                    Spacer()
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 570, height: 480)
    }

    func theLoopTimesView() -> some View {
        ZStack {
            if colorScheme == .dark {
                TheLoopTimes()
                    .fill(
                        .shadow(.inner(color: .black.opacity(0.1), radius: 3))
                            .shadow(.inner(color: .black.opacity(0.3), radius: 5, y: 3))
                    )
                    .foregroundStyle(.primary.opacity(0.7))
                    .blendMode(.overlay)
            } else {
                TheLoopTimes()
                    .foregroundStyle(.primary.opacity(0.7))
                    .blendMode(.overlay)

                TheLoopTimes()
                    .fill(
                        .shadow(.inner(color: .black.opacity(0.1), radius: 3))
                            .shadow(.inner(color: .black.opacity(0.3), radius: 5, y: 3))
                    )
                    .blendMode(.overlay)
            }

            TheLoopTimes()
                .stroke(.primary.opacity(0.1), lineWidth: 1)
                .blendMode(.luminosity)
        }
        .aspectRatio(883.88 / 135.53, contentMode: .fit)
        .frame(width: 450)
    }

    func versionChangeView() -> some View {
        ZStack {
            versionChangeText()
                .foregroundStyle(.primary.opacity(0.7))
                .blendMode(.overlay)

            if colorScheme == .light {
                versionChangeText()
                    .blendMode(.overlay)
            }
        }
    }

    func versionChangeText() -> some View {
        HStack {
            if let targetRelease = updater.targetRelease {
                // Use UserDefaults to check if development versions are included
                let isDevBuild = UserDefaults.standard.bool(forKey: "includeDevelopmentVersions")
                let targetIsDevBuild = targetRelease.prerelease
                let devBuildEmoji = "🧪 "

                let currentVersionBase = Bundle.main.appVersion?.replacingOccurrences(of: devBuildEmoji, with: "") ?? "Unknown"
                // Apply devBuildEmoji based on UserDefaults setting
                let currentVersion = "\(isDevBuild ? devBuildEmoji : "")\(currentVersionBase) (\(Bundle.main.appBuild ?? 0))"
                Text(currentVersion)

                Image(systemName: "arrow.right")

                let newVersionBase = targetRelease.tagName.replacingOccurrences(of: devBuildEmoji, with: "")
                // Apply devBuildEmoji to the new version if it's a dev build and the setting is enabled
                let newVersion = "\(targetIsDevBuild && isDevBuild ? devBuildEmoji : "")\(newVersionBase) (\(targetRelease.buildNumber ?? 0))"
                Text(newVersion)
            } else {
                let currentVersion = Bundle.main.appVersion ?? "Unknown"
                Text(currentVersion)

                Image(systemName: "arrow.right")

                let newVersion = "Unknown"
                Text(newVersion)
            }
        }
    }

    func changelogView() -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack {
                ForEach(updater.changelog, id: \.title) { item in
                    if !item.body.isEmpty {
                        ChangelogSectionView(item: item)
                    }
                }
            }
            .padding(.top, 10)
            .padding(12)
        }
    }
}

struct ChangelogSectionView: View {
    @Environment(\.luminareAnimation) var luminareAnimation
    @State var isExpanded = false
    let item: (title: String, body: [Updater.ChangelogNote])

    var body: some View {
        LuminareSection {
            Button {
                withAnimation(luminareAnimation) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(.chevronRight)
                        .bold()
                        .rotationEffect(isExpanded ? .degrees(90) : .zero)

                    Text(LocalizedStringKey(item.title))
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.horizontal, 8)
                .frame(height: 34)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(item.body, id: \.id) { note in
                    HStack(spacing: 8) {
                        Text(note.emoji)
                        Text(LocalizedStringKey(note.text))
                            .lineSpacing(1.1)

                        Spacer(minLength: 0)

                        HStack(spacing: 0) {
                            if let user = note.user {
                                let text = "@\(user)"
                                Link(text, destination: URL(string: "https://github.com/\(user)")!)
                                    .frame(width: 105, alignment: .trailing)
                            }

                            if note.user != nil, note.user != nil {
                                let text = "•" // Prevents unnecessary localization entries
                                Text(text)
                                    .padding(.horizontal, 4)
                            }

                            if let reference = note.reference {
                                let text = "#\(reference)"
                                Link(text, destination: URL(string: "https://github.com/MrKai77/Loop/issues/\(reference)")!)
                                    .frame(width: 35, alignment: .leading)
                                    .monospaced()
                            }
                        }
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)
                        .fixedSize()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(minHeight: 34)
                }
            }
        }
    }
}
