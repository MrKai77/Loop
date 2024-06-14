//
//  AboutConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-26.
//

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

    let credits: [CreditItem] = [
        .init(
            "Kai",
            "Development",
            url: .init(string: "https://github.com/mrkai77")!,
            avatar: .init(string: "https://github.com/mrkai77.png?size=200")!
        ),
        .init(
            "Jace",
            "Design",
            url: .init(string: "https://x.com/jacethings")!,
            avatar: .init(string: "https://github.com/soft-bred.png?size=200")!
        ),
        .init(
            "Kami",
            "Development support",
            url: .init(string: "https://github.com/senpaihunters")!,
            avatar: .init(string: "https://github.com/senpaihunters.png?size=200")!
        ),
        .init(
            "Greg Lassale",
            "Icon contributor",
            url: .init(string: "https://x.com/greglassale")!,
            avatar: .init(string: "https://pbs.twimg.com/profile_images/1746348765127094272/eNO2LxOQ_200x200.jpg")!
        ),
        .init(
            "JSDev",
            "Icon contributor",
            url: .init(string: "https://github.com/N-coder82")!,
            avatar: .init(string: "https://github.com/n-coder82.png?size=200")!
        ),
        .init(
            "Contributors on GitHub",
            "Some features, ideas, and bug fixes",
            url: .init(string: "https://github.com/MrKai77/Loop/graphs/contributors")!,
            avatar: .init(string: "https://github.githubassets.com/assets/GitHub-Mark-ea2971cee799.png?size=200")!
        )
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
    let avatar: URL

    init(_ name: String, _ description: LocalizedStringKey? = nil, url: URL, avatar: URL) {
        self.name = name
        self.description = description
        self.avatar = avatar
        self.url = url
    }
}

struct AboutConfigurationView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var model = AboutConfigurationModel()
    @StateObject var updater = SoftwareUpdater()
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

                        Text(model.isHoveringOverVersionCopier ? 
                            "Version \(Bundle.main.appVersion) (\(Bundle.main.appBuild))" :
                            "You've looped \(timesLooped) times!"
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
            Button("Check for updates…") {
                updater.checkForUpdates()
            }

            LuminareToggle("Automatically check for updates", isOn: $updater.automaticallyChecksForUpdates)
            LuminareToggle("Include development versions", isOn: $model.includeDevelopmentVersions)
        }

        LuminareSection {
            VStack(alignment: .leading, spacing: 12) {
                Text("Click on 'Send Feedback' to go to our GitHub page, where you can report bugs, suggest new features, or provide other valuable input.")

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
                AsyncImage(url: credit.avatar) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "person.crop.circle")
                        .resizable()
                        .foregroundStyle(.tertiary)
                        .aspectRatio(contentMode: .fit)
                }
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
