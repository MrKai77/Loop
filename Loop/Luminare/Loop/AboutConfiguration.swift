//
//  AboutConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-26.
//

import Combine
import Defaults
import Luminare
import SwiftUI

class AboutConfigurationModel: ObservableObject {
    let currentIcon = Defaults[.currentIcon] // no need for didSet since it won't change here

    @Published var isHoveringOverVersionCopier = false

    @Published var includeDevelopmentVersions = Defaults[.includeDevelopmentVersions] {
        didSet {
            Defaults[.includeDevelopmentVersions] = includeDevelopmentVersions
        }
    }

    @Published var updateButtonTitle: LocalizedStringKey = "Check for updates…"

    let credits: [CreditItem] = [
        .init(
            "Kai",
            "Development",
            url: .init(string: "https://github.com/mrkai77")!,
            avatar: Image(.kai)
        ),
        .init(
            "Jace",
            "Design",
            url: .init(string: "https://x.com/jacethings")!,
            avatar: Image(.jace)
        ),
        .init(
            "Kami",
            "Development support",
            url: .init(string: "https://github.com/senpaihunters")!,
            avatar: Image(.kami)
        ),
        .init(
            "Greg Lassale",
            "Icon contributor",
            url: .init(string: "https://x.com/greglassale")!,
            avatar: Image(.greglassale)
        ),
        .init(
            "JSDev",
            "Icon contributor",
            url: .init(string: "https://github.com/N-coder82")!,
            avatar: Image(.jsdev)
        ),
        .init(
            "Contributors on GitHub",
            "Some features, ideas, and bug fixes",
            url: .init(string: "https://github.com/MrKai77/Loop/graphs/contributors")!,
            avatar: Image(.github)
        )
    ]

    let upToDateText: [LocalizedStringKey] = [
        "You're up to date :)",
        "No updates yet!",
        "You've already got the best Loop!",
        "Check back next time!",
        "This is not the update you're looking for!",
        "Stay sharp, more intel coming soon!",
        "May the Force be with you... next time!",
        "The Force is strong with this version!",
        "You’ve leveled up to max!",
        "You've got the precious, no updates needed!",
        "No new intel, Commander."
    ]

    func copyVersionToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(
            "Version \(Bundle.main.appVersion) (\(Bundle.main.appBuild))",
            forType: NSPasteboard.PasteboardType.string
        )
    }
}

struct CreditItem: Identifiable {
    var id: String { name }

    let name: String
    let description: LocalizedStringKey?
    let url: URL
    let avatar: Image

    init(_ name: String, _ description: LocalizedStringKey? = nil, url: URL, avatar: Image) {
        self.name = name
        self.description = description
        self.avatar = avatar
        self.url = url
    }
}

struct AboutConfigurationView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var model = AboutConfigurationModel()
    @ObservedObject private var updater = AppDelegate.updater
    @Default(.timesLooped) var timesLooped

    var body: some View {
        LuminareSection {
            Button {
                model.copyVersionToClipboard()
            } label: {
                HStack {
                    if let image = NSImage(named: model.currentIcon) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 60)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Loop")
                            .fontWeight(.medium)

                        Text(
                            model.isHoveringOverVersionCopier
                                ? "Version \(Bundle.main.appVersion) (\(Bundle.main.appBuild))"
                                : "You've looped \(timesLooped) times!"
                        )
                        .contentTransition(.numericText(countsDown: !model.isHoveringOverVersionCopier))
                        .animation(.smooth(duration: 0.25), value: model.isHoveringOverVersionCopier)
                        .animation(.smooth(duration: 0.25), value: timesLooped)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(4)
            }
            .buttonStyle(LuminareCosmeticButtonStyle(Image(._12PxClipboard)))
            .onHover {
                model.isHoveringOverVersionCopier = $0
            }
        }

        LuminareSection {
            Button {
                Task {
                    await updater.fetchLatestInfo()

                    if updater.updateState == .available {
                        updater.showUpdateWindow()
                    } else {
                        model.updateButtonTitle = model.upToDateText.randomElement()!

                        let currentTitle = model.updateButtonTitle
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            if model.updateButtonTitle == currentTitle {
                                model.updateButtonTitle = "Check for updates…"
                            }
                        }
                    }
                }
            } label: {
                Text(model.updateButtonTitle)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.25), value: model.updateButtonTitle)
            }

            // I do not have the code for you to automatically check, it is hardcoded though...
            // LuminareToggle("Automatically check for updates", isOn: $updater.automaticallyChecksForUpdates)
            LuminareToggle("Include development versions", isOn: $model.includeDevelopmentVersions)
        }

        LuminareSection {
            VStack(alignment: .leading, spacing: 12) {
                Text(
                    "Click on 'Send Feedback' to go to our GitHub page, where you can report bugs, suggest new features, or provide other valuable input."
                )

                Button("Send Feedback") {
                    openURL(URL(string: "https://github.com/MrKai77/Loop")!)
                }
                .buttonStyle(LuminareCompactButtonStyle())
            }
            .padding(8)
        }

        LuminareSection("Credits") {
            ForEach(model.credits) { credit in
                creditsView(credit)
            }
        }
    }

    @ViewBuilder
    func creditsView(_ credit: CreditItem) -> some View {
        Button {
            openURL(credit.url)
        } label: {
            HStack(spacing: 12) {
                credit.avatar
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 40)
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    }
                    .clipShape(.circle)

                VStack(alignment: .leading) {
                    Text(credit.name)

                    if let description = credit.description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(12)
        }
        .buttonStyle(LuminareCosmeticButtonStyle(Image(._12PxShareUpRight)))
    }
}
