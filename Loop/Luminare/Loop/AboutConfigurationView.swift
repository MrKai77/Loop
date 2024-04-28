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

                    Text("Version \(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
    }
}
