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
    @Default(.hapticFeedback) var hapticFeedback
    @Default(.hideUntilDirectionIsChosen) var hideUntilDirectionIsChosen
    @Default(.sizeIncrement) var sizeIncrement
    @Default(.animateWindowResizes) var animateWindowResizes
    @Default(.includeDevelopmentVersions) var includeDevelopmentVersions
    @State var isAccessibilityAccessGranted = false
    @State var isScreenRecordingAccessGranted = false

    var body: some View {
        Form {
            Section(content: {
                Toggle("Automatically check for updates", isOn: $updater.automaticallyChecksForUpdates)
                Toggle("Include development versions", isOn: $includeDevelopmentVersions)
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
                            let versionText = String(
                                localized: "Current version: \(Bundle.main.appVersion) (\(Bundle.main.appBuild))"
                            )
                            HStack {
                                Text("\(versionText) \(Image(systemName: "doc.on.clipboard"))")
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

                CrispValueAdjuster(
                    .init(localized: .init("Crisp Value Adjuster: Stage Strip Size", defaultValue: "Stage strip size")),
                    value: $stageStripSize,
                    sliderRange: 50...200,
                    postscript: .init(localized: .init("px", defaultValue: "px")),
                    lowerClamp: true
                )
                .disabled(!respectStageManager)
            }

            Section("Advanced") {
                Toggle(isOn: $animateWindowResizes) {
                    HStack {
                        Text("Animate windows being resized")
                        UnstableIndicator(.init(localized: .init("ALPHA", defaultValue: "ALPHA")), color: .orange)
                    }
                }
                .onChange(of: animateWindowResizes) { _ in
                    if animateWindowResizes == true {
                        PermissionsManager.ScreenRecording.requestAccess()
                    }
                }

                Toggle("Hide menu until direction is chosen", isOn: $hideUntilDirectionIsChosen)

                Toggle("Haptic feedback", isOn: $hapticFeedback)

                CrispValueAdjuster(
                    .init(localized: .init("Crisp Value Adjuster: Size Increment", defaultValue: "Size increment")),
                    description: .init(
                        localized: .init(
                            "Crisp Value Adjuster: Size Increment Description",
                            defaultValue: "Used in size adjustment window actions"
                        )
                    ),
                    value: $sizeIncrement,
                    sliderRange: 5...50,
                    postscript: .init(localized: .init("px", defaultValue: "px")),
                    step: 4.5,
                    lowerClamp: true
                )
            }

            Section(content: {
                HStack {
                    Text("Accessibility access")
                    Spacer()
                    Text(
                        isAccessibilityAccessGranted
                        ? .init(localized: .init("Granted", defaultValue: "Granted"))
                        : .init(localized: .init("Not granted", defaultValue: "Not granted"))
                    )
                    Circle()
                        .frame(width: 8, height: 8)
                        .padding(.trailing, 5)
                        .foregroundColor(isAccessibilityAccessGranted ? .green : .red)
                        .shadow(color: isAccessibilityAccessGranted ? .green : .red, radius: 8)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Screen recording access")
                        Spacer()
                        Text(
                            isAccessibilityAccessGranted
                            ? .init(localized: .init("Granted", defaultValue: "Granted"))
                            : .init(localized: .init("Not granted", defaultValue: "Not granted"))
                        )
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
                    Text("""
Sending feedback will bring you to our \"New Issue\" GitHub page, where you can report a bug, request a feature & more!
""")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Spacer()

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
