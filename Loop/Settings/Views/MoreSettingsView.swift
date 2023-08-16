//
//  MoreSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-28.
//

import SwiftUI
import Sparkle

struct MoreSettingsView: View {

    @EnvironmentObject var updater: SoftwareUpdater

    var body: some View {
        Form {
            Section(content: {
                Toggle("Automatically check for updates", isOn: $updater.automaticallyChecksForUpdates)
                Toggle("Include development versions", isOn: $updater.includeDevelopmentVersions)
            }, header: {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Updates")
                        Text("Current version: \(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Check for Updates…") {
                        updater.checkForUpdates()
                    }
                    .buttonStyle(.link)
                    .foregroundStyle(Color.accentColor)
                }
            })
        }
        .formStyle(.grouped)
    }
}
