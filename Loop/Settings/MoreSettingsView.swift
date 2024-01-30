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
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var updater: SoftwareUpdater

    @Default(.respectStageManager) var respectStageManager
    @Default(.stageStripSize) var stageStripSize
    @Default(.enableHapticFeedback) var enableHapticFeedback
    @Default(.animateWindowResizes) var animateWindowResizes
    @State var isAccessibilityAccessGranted = false
    @State var isScreenRecordingAccessGranted = false

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
                            HStack {
                                Text("Current version: \(Bundle.main.appVersion) (\(Bundle.main.appBuild)) \(Image(systemName: "doc.on.clipboard"))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
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

            Section("Stage Manager") {
                Toggle("Respect Stage Manager", isOn: $respectStageManager)
                Slider(
                    value: $stageStripSize,
                    in: 50...200,
                    step: 15,
                    minimumValueLabel: Text("50px"),
                    maximumValueLabel: Text("200px")
                ) {
                    Text("Stage Strip Size")
                }
                .disabled(!respectStageManager)
            }

            Section("Accessibility") {
                Toggle("Enable Haptic Feedback", isOn: $enableHapticFeedback)
            }

            Section(content: {
                HStack {
                    Text("Accessibility Access")
                    Spacer()
                    Text(isAccessibilityAccessGranted ? "Granted" : "Not Granted")
                    Circle()
                        .frame(width: 8, height: 8)
                        .padding(.trailing, 5)
                        .foregroundColor(isAccessibilityAccessGranted ? .green : .red)
                        .shadow(color: isAccessibilityAccessGranted ? .green : .red, radius: 8)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Screen Recording Access")
                        Spacer()
                        Text(isScreenRecordingAccessGranted ? "Granted" : "Not Granted")
                        Circle()
                            .frame(width: 8, height: 8)
                            .padding(.trailing, 5)
                            .foregroundColor(isScreenRecordingAccessGranted ? .green : .red)
                            .shadow(color: isScreenRecordingAccessGranted ? .green : .red, radius: 8)
                    }
                    Text("This is only needed to animate windows being resized.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }, header: {
                HStack {
                    Text("Permissions")

                    Spacer()

                    Button("Request Access…", action: {
                        PermissionsManager.requestAccess()
                        self.isAccessibilityAccessGranted = PermissionsManager.Accessibility.getStatus()
                        self.isScreenRecordingAccessGranted = PermissionsManager.ScreenRecording.getStatus()
                    })
                    .buttonStyle(.link)
                    .foregroundStyle(Color.accentColor)
                    .disabled(isAccessibilityAccessGranted && isScreenRecordingAccessGranted)
                    .opacity(isAccessibilityAccessGranted ? isScreenRecordingAccessGranted ? 0.6 : 1 : 1)
                    .onAppear {
                        self.isAccessibilityAccessGranted = PermissionsManager.Accessibility.getStatus()
                        self.isScreenRecordingAccessGranted = PermissionsManager.ScreenRecording.getStatus()

                        if !isScreenRecordingAccessGranted {
                            self.animateWindowResizes = false
                        }
                    }
                }
            })

            Section("Feedback") {
                HStack {
                    Text(
                        "Sending feedback will bring you to our \"New Issue\" page, " +
                        "where you can select a template to report a bug, request a feature & more!"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Button(action: {
                        openURL(URL(string: "https://github.com/MrKai77/Loop/issues/new/choose")!)
                    }, label: {
                        Text("Send Feedback")
                    })
                    .controlSize(.large)
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
