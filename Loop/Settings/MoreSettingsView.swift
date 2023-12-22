//
//  MoreSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-28.
//

import SwiftUI
import Sparkle
import Defaults

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
                        Button(action: {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(
                                "Version \(Bundle.main.appVersion) (\(Bundle.main.appBuild))",
                                forType: NSPasteboard.PasteboardType.string
                            )
                        }, label: {
                            // swiftlint:disable:next line_length
                            Text("Current version: \(Bundle.main.appVersion) (\(Bundle.main.appBuild)) \(Image(systemName: "doc.on.clipboard"))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        })
                        .buttonStyle(.plain)
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
        .scrollDisabled(true)
    }
}
