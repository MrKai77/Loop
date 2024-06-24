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
    private var shuffledTexts: [LocalizedStringKey] = [] // Store the shuffled texts

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
            .init(localized: "Contributors on GitHub"),
            "Some features, ideas, and bug fixes",
            url: .init(string: "https://github.com/MrKai77/Loop/graphs/contributors")!,
            avatar: Image(.github)
        )
    ]

    // A max of 28 W's can fit in here :)
    var upToDateText: [LocalizedStringKey] = [
        "Engage! ...in the current version, it's the latest.",
        "This app is more up to date than my diary entries!",
        "You're in the clear, no updates in the atmosphere!",
        "The odds are ever in your favor, no updates today!",
        "Our app is on a digital diet. No new bytes allowed.",
        "New version? Sorry, we're too attached to this one.",
        "Your Loop is loopier than ever, no updates found!",
        "I'm giving it all she's got, Captain! No updates!",
        "In a galaxy far, far away... still no updates!",
        "You've got the precious, no updates needed!",
        "Riding at warp speed, no updates in sight!",
        "This is not the update you're looking for!",
        "We've misplaced the 'Update' button. Oops!",
        "I swear it was here somewhere... one sec",
        "An apple a day keeps the... updates away.",
        "May the Force be with you... next time!",
        "The Force is strong with this version!",
        "Just a small town app, same old version",
        "Winter is coming. Updates aren't yet.",
        "Sweet dreams are made of... no updates",
        "The update fairy skipped us this week.",
        "Stay sharp, more intel coming soon!",
        "You're cruising on the latest tech!",
        "We’ll be back. With updates... later",
        "A penny for your... lack of updates.",
        "You've already got the best Loop!",
        "One does not simply update Loop.",
        "All work and no... no updates...",
        "A watched pot never... updates.",
        "99 problems, updates ain't one.",
        "I... uhh... one sec I lost it",
        "You’ve leveled up to the max!",
        "Beggars can't be... updaters.",
        "Money can't buy... updates.",
        "No new intel, Commander.",
        "No updates? Great Scott!",
        "No updates, Mr. Anderson",
        "No updates in Ba Sing Se",
        "Updates? In this economy?",
        "Check back next time!",
        "Loop is in its prime!",
        "All systems are a-go!",
        "You're up to date :)",
        "No updates yet!"
    ]

    func getNextUpToDateText() -> LocalizedStringKey {
        // If shuffledTexts is empty, fill it with a shuffled version of upToDateText
        if shuffledTexts.isEmpty {
            shuffledTexts = upToDateText.shuffled()
        }
        // Pop the last element to ensure it's not repeated until all have been shown
        return shuffledTexts.popLast() ?? "Check for updates…" // Fallback string
    }

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
                        Text(Bundle.main.appName)
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
                        // Use getNextUpToDateText to get the next text
                        model.updateButtonTitle = model.getNextUpToDateText()

                        // Reset the title after 2 seconds
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

            // LuminareToggle("Automatically check for updates", isOn: $updater.automaticallyChecksForUpdates)
            // LuminareToggle("Include development versions", isOn: $model.includeDevelopmentVersions)
            /// I can't see to have it use `$model`, it won't update but if i use `$updater` it will...
            /// Can i fix the issue? NOPE, therefore, no longer my issue :smile:
            LuminareToggle("Include development versions", isOn: $updater.includeDevelopmentVersions)
        }

        LuminareSection {
            Text(
                "Share feedback on our GitHub page, where you can let us know about any bugs, suggest features, or provide other valuable input. We also accept donations if you feel that Loop has improved your workflow :)"
            )
            .padding(8)

            HStack(spacing: 2) {
                Button("Send Feedback") {
                    openURL(URL(string: "https://github.com/MrKai77/Loop")!)
                }

                Button("Donate") {
                    openURL(URL(string: "https://github.com/sponsors/MrKai77")!)
                }
            }
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
