//
//  AboutConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-26.
//

import SwiftUI
import Luminare
import Defaults

struct AboutConfigurationView: View {
    @Environment(\.openURL) private var openURL

    @Default(.currentIcon) var currentIcon
    @Default(.includeDevelopmentVersions) var includeDevelopmentVersions

    @StateObject private var updater = SoftwareUpdater()

    let credits: [CreditItem] = [
        .init(
            "Kai",
            "Development",
            .init(string: "https://github.com/mrkai77")!,
            avatar: .init(string: "https://github.com/mrkai77.png?size=200")!
        ),
        .init(
            "Jace",
            "Design",
            .init(string: "https://x.com/jacethings")!,
            avatar: .init(string: "https://github.com/soft-bred.png?size=200")!
        ),
        .init(
            "Kami",
            "Development support",
            .init(string: "https://github.com/senpaihunters")!,
            avatar: .init(string: "https://github.com/senpaihunters.png?size=200")!
        ),
        .init(
            "Greg Lassale",
            "Icon contributor",
            .init(string: "https://x.com/greglassale")!,
            avatar: .init(string: "https://pbs.twimg.com/profile_images/1746348765127094272/eNO2LxOQ_200x200.jpg")!
        )
    ]

    struct CreditItem: Identifiable {
        var id: String { name }

        let name: String
        let description: LocalizedStringKey
        let url: URL
        let avatar: URL

        init(_ name: String, _ description: LocalizedStringKey, _ url: URL, avatar: URL) {
            self.name = name
            self.description = description
            self.avatar = avatar
            self.url = url
        }
    }

    var body: some View {
        LuminareSection {
            HStack {
                if let image = NSImage(named: currentIcon) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 60)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Loop")
                        .fontWeight(.medium)

                    Button {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(
                            "Version \(Bundle.main.appVersion) (\(Bundle.main.appBuild))",
                            forType: NSPasteboard.PasteboardType.string
                        )
                    } label: {
                        let versionText = String(
                            localized: "Version \(Bundle.main.appVersion) (\(Bundle.main.appBuild))"
                        )
                        Text("\(versionText) \(Image(systemName: "doc.on.clipboard"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()
            }
            .padding(4)
        }

        LuminareSection {
            Button("Check for updates…") {
                updater.checkForUpdates()
            }

            LuminareToggle("Automatically check for updates", isOn: $updater.automaticallyChecksForUpdates)
            LuminareToggle("Include development versions", isOn: $includeDevelopmentVersions)
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
            ForEach(credits) { credit in
                creditsView(credit)
            }
        }

        Button {
            openURL(URL(string: "https://github.com/MrKai77/Loop/graphs/contributors")!)
        } label: {
            Text("…and all the awesome open source contributors on GitHub!", comment: "End of credits in about tab")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    func creditsView(_ credit: CreditItem) -> some View {
        Button {
            openURL(credit.url)
        } label: {
            HStack(spacing: 8) {
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
                    Text(credit.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
