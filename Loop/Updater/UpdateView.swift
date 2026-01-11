//
//  UpdateView.swift
//  Loop
//
//  Created by Kami on 15/06/2024.
//

import Defaults
import Luminare
import SwiftUI

struct UpdateView: View {
    @Environment(\.luminareTintColor) var tintColor
    @Environment(\.luminareAnimation) var luminareAnimation
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var updater = Updater.shared

    @Default(.currentIcon) private var currentIcon

    @State private var isShowingTheLoopTimes: Bool = false
    @State private var isInstalling: Bool = false
    @State private var readyToRestart: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                if isShowingTheLoopTimes {
                    theLoopTimesView()
                        .padding(.top, 18)
                        .padding(.bottom, 8)
                        .contentShape(.rect)
                        .onTapGesture {
                            withAnimation(.smooth(duration: 0.25)) {
                                isShowingTheLoopTimes.toggle()
                            }
                        }

                    VStack(spacing: 4) {
                        Divider()

                        updateDateView()

                        Divider()
                    }
                } else {
                    appIconView()
                        .onTapGesture {
                            withAnimation(.smooth(duration: 0.25)) {
                                isShowingTheLoopTimes.toggle()
                            }
                        }

                    versionChangeView()
                }
            }

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

            footerView()
        }
        .frame(width: 500, height: 480)
    }

    @ViewBuilder
    private func theLoopTimesView() -> some View {
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
        .frame(width: 400)
    }

    @ViewBuilder
    private func appIconView() -> some View {
        if let image = NSImage(named: currentIcon) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 128)
        }
    }

    private func updateDateView() -> some View {
        ZStack {
            if let updateDate = updater.targetRelease?.updateDate {
                Text(updateDate.formatted(date: .complete, time: .shortened))
                    .fontDesign(.serif)
                    .foregroundStyle(.tertiary)
                    .fontWeight(.medium)
            } else {
                versionChangeView()
            }
        }
    }

    private func versionChangeView() -> some View {
        ZStack {
            versionChangeText()
                .foregroundStyle(.tertiary)
                .fontWeight(.medium)
        }
    }

    private func versionChangeText() -> some View {
        HStack {
            if let targetRelease = updater.targetRelease {
                let devBuildEmoji = "🧪"
                let currentIsDevBuild: Bool = Bundle.main.appVersion?.contains(devBuildEmoji) ?? false
                let targetIsDevBuild = targetRelease.prerelease

                let currentVersionBase = Bundle.main.appVersion?.replacing(devBuildEmoji, with: "").trimmingCharacters(in: .whitespaces)
                let targetVersionBase = targetRelease.tagName.replacing(devBuildEmoji, with: "").trimmingCharacters(in: .whitespaces)

                let currentVersionBuild = currentIsDevBuild ? " (\(Bundle.main.appBuild ?? 0))" : ""
                let targetVersionBuild = targetIsDevBuild ? " (\(targetRelease.buildNumber ?? 0))" : ""

                let currentVersion = "\(currentIsDevBuild ? devBuildEmoji : "")\(currentVersionBase ?? "Unknown")\(currentVersionBuild)"
                Text(currentVersion)

                Image(systemName: "arrow.right")

                let targetVersion = "\(targetIsDevBuild ? devBuildEmoji : "")\(targetVersionBase)\(targetVersionBuild)"
                Text(targetVersion)
            } else {
                let currentVersion = Bundle.main.appVersion ?? "Unknown"
                Text(currentVersion)

                Image(systemName: "arrow.right")

                let targetVersion = "Unknown"
                Text(targetVersion)
            }
        }
    }

    private func changelogView() -> some View {
        ScrollView(showsIndicators: false) {
            VStack { // Using LazyVStack seems to cause visual glitches
                ForEach(updater.changelog, id: \.title) { item in
                    if !item.body.isEmpty {
                        ChangelogSectionView(
                            isExpanded: Binding(
                                get: {
                                    updater.expandedChangelogSections.contains(item.title)
                                },
                                set: { newValue in
                                    if newValue {
                                        updater.expandedChangelogSections.insert(item.title)
                                    } else {
                                        updater.expandedChangelogSections.remove(item.title)
                                    }
                                }
                            ),
                            item: item
                        )
                    }
                }
            }
            .padding(.top, 10)
            .padding(12)
        }
    }

    private func footerView() -> some View {
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
                            .padding(.horizontal, 12)
                    }

                    let tenSpaces = "          " // This helps with alignment for the animation once the update finishes
                    Text(isInstalling ? tenSpaces : readyToRestart ? NSLocalizedString("Relaunch to complete", comment: "") : NSLocalizedString("Install", comment: ""))
                        .contentTransition(.numericText())
                        .opacity(isInstalling ? 0 : 1)
                }
            }
            .allowsHitTesting(!isInstalling)
        }
        .luminareCornerRadius(8)
        .padding(12)
        .overlay {
            VStack {
                Divider()
                Spacer()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ChangelogSectionView: View {
    @Environment(\.luminareAnimation) var luminareAnimation
    @Environment(\.luminareCornerRadii) var luminareCornerRadii

    @Binding var isExpanded: Bool
    let item: (title: String, body: [Updater.ChangelogNote])

    var body: some View {
        LuminareSection {
            Button {
                withAnimation(luminareAnimation) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "chevron.forward")
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
