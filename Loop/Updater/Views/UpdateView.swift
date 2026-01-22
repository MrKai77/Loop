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
            if let updateDate = updater.targetRelease?.updatedAt {
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
        let currentVersion = VersionDisplay.formatCurrentAppVersion()

        // If no target release (after installation), just show current version (without emoji)
        guard let targetRelease = updater.targetRelease else {
            let cleanVersion = currentVersion.displayString.replacingOccurrences(of: "🧪 ", with: "")
            return AnyView(
                HStack {
                    Text("Installed:")
                    Spacer()
                    Text(cleanVersion)
                        .fontWeight(.semibold)
                }
            )
        }

        let targetVersion = targetRelease.formattedVersion(current: nil, build: nil)

        // Strip emoji from current version display for cleaner UI
        let cleanCurrentVersion = currentVersion.displayString.replacingOccurrences(of: "🧪 ", with: "")

        return AnyView(
            HStack {
                Text(cleanCurrentVersion)
                Image(systemName: "arrow.right")
                Text(targetVersion.displayString)
            }
        )
    }

    private func changelogView() -> some View {
        ScrollView(showsIndicators: false) {
            VStack { // Using LazyVStack seems to cause visual glitches
                ForEach(updater.changelog, id: \.title) { item in
                    if !item.body.isEmpty {
                        let isExpanded = updater.expandedChangelogSections.contains(item.title)
                        ChangelogSectionView(
                            isExpanded: isExpanded,
                            title: item.title,
                            notes: item.body,
                            onToggle: {
                                withAnimation(.smooth(duration: 0.25)) {
                                    if isExpanded {
                                        updater.expandedChangelogSections.remove(item.title)
                                    } else {
                                        updater.expandedChangelogSections.insert(item.title)
                                    }
                                }
                            }
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

                    try? await Task.sleep(for: .seconds(1))

                    withAnimation(luminareAnimation) {
                        isInstalling = false
                        readyToRestart = true
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

struct ChangelogSectionView: View, Equatable {
    @Environment(\.luminareAnimation) var luminareAnimation

    let isExpanded: Bool
    let title: String
    let notes: [Updater.ChangelogNote]
    let onToggle: () -> ()

    var body: some View {
        LuminareSection {
            SectionHeader(isExpanded: isExpanded, title: title, animation: luminareAnimation, onToggle: onToggle)

            if isExpanded {
                ForEach(notes, id: \.id) { note in
                    ChangelogItemView(note: note)
                }
            }
        }
    }

    static func == (lhs: ChangelogSectionView, rhs: ChangelogSectionView) -> Bool {
        lhs.isExpanded == rhs.isExpanded &&
            lhs.title == rhs.title &&
            lhs.notes == rhs.notes
    }
}

private struct SectionHeader: View, Equatable {
    let isExpanded: Bool
    let title: String
    let animation: Animation?
    let onToggle: () -> ()

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack {
                Image(systemName: "chevron.forward")
                    .bold()
                    .rotationEffect(isExpanded ? .degrees(90) : .zero)

                Text(LocalizedStringKey(title))
                    .font(.headline)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 34)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    static func == (lhs: SectionHeader, rhs: SectionHeader) -> Bool {
        lhs.isExpanded == rhs.isExpanded && lhs.title == rhs.title
    }
}

private struct ChangelogItemView: View, Equatable {
    let note: Updater.ChangelogNote

    var body: some View {
        HStack(spacing: 8) {
            Text(note.emoji)
            Text(LocalizedStringKey(note.text))
                .lineSpacing(1.1)

            Spacer(minLength: 0)

            ChangelogMetadataView(note: note)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(minHeight: 34)
    }

    static func == (lhs: ChangelogItemView, rhs: ChangelogItemView) -> Bool {
        lhs.note == rhs.note
    }
}

private struct ChangelogMetadataView: View, Equatable {
    let note: Updater.ChangelogNote

    var body: some View {
        HStack(spacing: 0) {
            if let user = note.user {
                Link(String("@\(user)"), destination: URL(string: "https://github.com/\(user)")!)
                    .frame(width: 105, alignment: .trailing)
            }

            if note.user != nil, note.reference != nil {
                Text(verbatim: "•")
                    .padding(.horizontal, 4)
            }

            if let reference = note.reference {
                Link(String("#\(reference)"), destination: URL(string: "https://github.com/MrKai77/Loop/issues/\(reference)")!)
                    .monospaced()
                    .fixedSize()
            }
        }
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
        .fixedSize()
    }

    static func == (lhs: ChangelogMetadataView, rhs: ChangelogMetadataView) -> Bool {
        lhs.note.user == rhs.note.user && lhs.note.reference == rhs.note.reference
    }
}

// MARK: - Bundle Info Helpers

private enum BundleInfoReader {
    static func readVersionInfo(from bundleURL: URL) -> (version: String, build: Int)? {
        let infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist")

        guard let plist = NSDictionary(contentsOf: infoPlistURL),
              let version = plist["CFBundleShortVersionString"] as? String,
              let buildString = plist["CFBundleVersion"] as? String,
              let build = Int(buildString) else {
            return nil
        }

        return (version, build)
    }
}

// MARK: - Version Display Helpers

private struct VersionDisplay {
    let displayString: String

    static let unknown = VersionDisplay(displayString: "Unknown")

    static func formatCurrentAppVersion() -> VersionDisplay {
        // Read from the actual installed app's Info.plist, not the in-memory bundle
        let bundleURL = Bundle.main.bundleURL

        guard let (version, build) = BundleInfoReader.readVersionInfo(from: bundleURL) else {
            return .unknown
        }

        // Display version with emoji stripped for cleaner UI
        let cleanVersion = version.replacingOccurrences(of: "🧪 ", with: "")
        return VersionDisplay(displayString: "\(cleanVersion) (\(build))")
    }

    static func format(version: String?, build: Int?, isPrerelease: Bool) -> VersionDisplay {
        guard let version else {
            return .unknown
        }

        let devBuildEmoji = "🧪"
        let hasEmoji = version.contains(devBuildEmoji)
        let baseVersion = version.replacingOccurrences(of: devBuildEmoji, with: "").trimmingCharacters(in: .whitespaces)

        var displayString = baseVersion
        if isPrerelease || hasEmoji {
            displayString = "\(devBuildEmoji)\(baseVersion)"
        }

        if let build, hasEmoji || isPrerelease {
            displayString += " (\(build))"
        }

        return VersionDisplay(displayString: displayString)
    }
}

private extension Release {
    func formattedVersion(current: String?, build: Int?) -> VersionDisplay {
        let effectiveVersion: String
        let effectiveBuild: Int?

        if let current {
            effectiveVersion = current
            effectiveBuild = build
        } else {
            effectiveVersion = tagName
            effectiveBuild = buildNumber
        }

        return VersionDisplay.format(
            version: effectiveVersion,
            build: effectiveBuild,
            isPrerelease: prerelease
        )
    }
}
