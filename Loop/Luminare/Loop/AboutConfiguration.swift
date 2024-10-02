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

    @Published var updateButtonTitle: String = .init(localized: "Check for updates…")

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
            .init(localized: "Contributors on GitHub"),
            "Some features, ideas, and bug fixes",
            url: .init(string: "https://github.com/MrKai77/Loop/graphs/contributors")!,
            avatar: Image(.github)
        )
    ]

    // A max of 28 W's can fit in here :)
    var upToDateText: [String] = [
        .init(localized: "No updates available message 01", defaultValue: "Engage! …in the current version, it's the latest."),
        .init(localized: "No updates available message 02", defaultValue: "This app is more up to date than my diary entries!"),
        .init(localized: "No updates available message 03", defaultValue: "You're in the clear, no updates in the atmosphere!"),
        .init(localized: "No updates available message 04", defaultValue: "The odds are ever in your favor, no updates today!"),
        .init(localized: "No updates available message 05", defaultValue: "Our app is on a digital diet. No new bytes allowed."),
        .init(localized: "No updates available message 06", defaultValue: "New version? Sorry, we're too attached to this one."),
        .init(localized: "No updates available message 07", defaultValue: "Your Loop is Loopier than ever, no updates found!"),
        .init(localized: "No updates available message 08", defaultValue: "I'm giving it all she's got, Captain! No updates!"),
        .init(localized: "No updates available message 09", defaultValue: "In a galaxy far, far away… still no updates!"),
        .init(localized: "No updates available message 10", defaultValue: "You've got the precious, no updates needed!"),
        .init(localized: "No updates available message 11", defaultValue: "Riding at warp speed, no updates in sight!"),
        .init(localized: "No updates available message 12", defaultValue: "This is not the update you're looking for!"),
        .init(localized: "No updates available message 13", defaultValue: "We've misplaced the 'Update' button. Oops!"),
        .init(localized: "No updates available message 14", defaultValue: "I swear it was here somewhere… one sec"),
        .init(localized: "No updates available message 15", defaultValue: "An apple a day keeps the… updates away."),
        .init(localized: "No updates available message 16", defaultValue: "May the Force be with you… next time!"),
        .init(localized: "No updates available message 17", defaultValue: "The Force is strong with this version!"),
        .init(localized: "No updates available message 18", defaultValue: "Just a small town app, same old version"),
        .init(localized: "No updates available message 19", defaultValue: "Winter is coming. Updates aren't yet."),
        .init(localized: "No updates available message 20", defaultValue: "Sweet dreams are made of… no updates"),
        .init(localized: "No updates available message 21", defaultValue: "The update fairy skipped us this week."),
        .init(localized: "No updates available message 22", defaultValue: "Stay sharp, more intel coming soon!"),
        .init(localized: "No updates available message 23", defaultValue: "You're cruising on the latest tech!"),
        .init(localized: "No updates available message 24", defaultValue: "We’ll be back. With updates… later"),
        .init(localized: "No updates available message 25", defaultValue: "A penny for your… lack of updates."),
        .init(localized: "No updates available message 26", defaultValue: "You've already got the best Loop!"),
        .init(localized: "No updates available message 27", defaultValue: "One does not simply update Loop."),
        .init(localized: "No updates available message 28", defaultValue: "All work and no… no updates…"),
        .init(localized: "No updates available message 29", defaultValue: "A watched pot never… updates."),
        .init(localized: "No updates available message 30", defaultValue: "99 problems, updates ain't one."),
        .init(localized: "No updates available message 31", defaultValue: "I… uhh… one sec I lost it"),
        .init(localized: "No updates available message 32", defaultValue: "You’ve leveled up to the max!"),
        .init(localized: "No updates available message 33", defaultValue: "Beggars can't be… updaters."),
        .init(localized: "No updates available message 34", defaultValue: "Money can't buy… updates."),
        .init(localized: "No updates available message 35", defaultValue: "No new intel, Commander."),
        .init(localized: "No updates available message 36", defaultValue: "No updates? Great Scott!"),
        .init(localized: "No updates available message 37", defaultValue: "No updates, Mr. Anderson"),
        .init(localized: "No updates available message 38", defaultValue: "No updates in Ba Sing Se"),
        .init(localized: "No updates available message 39", defaultValue: "Updates? In this economy?"),
        .init(localized: "No updates available message 40", defaultValue: "Check back next time!"),
        .init(localized: "No updates available message 41", defaultValue: "Loop is in its prime!"),
        .init(localized: "No updates available message 42", defaultValue: "All systems are a-go!"),
        .init(localized: "No updates available message 43", defaultValue: "You're up to date :)"),
        .init(localized: "No updates available message 44", defaultValue: "No updates yet!")
    ]
    private var shuffledTexts: [String] = []

    func getNextUpToDateText() -> String {
        // If shuffledTexts is empty, fill it with a shuffled version of upToDateText
        if shuffledTexts.isEmpty {
            shuffledTexts = upToDateText.filter { $0 != "-" }.shuffled()
        }
        // Pop the last element to ensure it's not repeated until all have been shown
        return shuffledTexts.popLast() ?? upToDateText[0] // Fallback string
    }

    func copyVersionToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(
            "Version \(Bundle.main.appVersion ?? "Unknown") (\(Bundle.main.appBuild ?? 0))",
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
                                ? "Version \(Bundle.main.appVersion ?? "Unknown") (\(Bundle.main.appBuild ?? 0))"
                                : (timesLooped >= 1_000_000 ? "You've looped… uhh… I… lost count…" : "You've looped \(timesLooped) times!")
                        )
                        .contentTransition(.numericText(countsDown: !model.isHoveringOverVersionCopier))
                        .animation(LuminareConstants.animation, value: model.isHoveringOverVersionCopier)
                        .animation(LuminareConstants.animation, value: timesLooped)
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
                        await updater.showUpdateWindow()
                    } else {
                        // Use getNextUpToDateText to get the next text
                        model.updateButtonTitle = model.getNextUpToDateText()

                        // Reset the title after 2 seconds
                        let currentTitle = model.updateButtonTitle
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            if model.updateButtonTitle == currentTitle {
                                model.updateButtonTitle = .init(localized: "Check for updates…")
                            }
                        }
                    }
                }
            } label: {
                Text(model.updateButtonTitle)
                    .contentTransition(.numericText())
                    .animation(LuminareConstants.animation, value: model.updateButtonTitle)
            }
            .onAppear {
                if updater.updateState == .available {
                    model.updateButtonTitle = .init(localized: "Update…")
                }
            }
            .onChange(of: updater.updateState) { _ in
                if updater.updateState == .available {
                    model.updateButtonTitle = .init(localized: "Update…")
                }
            }

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

                Button("Join Discord") {
                    openURL(URL(string: "https://discord.gg/2CZ2N6PKjq")!)
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
