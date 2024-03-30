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

                CrispValueAdjuster(
                    "Stage Strip Size",
                    value: $stageStripSize,
                    sliderRange: 50...200,
                    postscript: "px",
                    lowerClamp: true
                )
                .disabled(!respectStageManager)
            }

            Section("Advanced") {
                Toggle(isOn: $animateWindowResizes) {
                    HStack {
                        Text("Animate windows being resized")
                        UnstableIndicator("ALPHA", color: .orange)
                    }
                }
                .onChange(of: animateWindowResizes) { _ in
                    if animateWindowResizes == true {
                        PermissionsManager.ScreenRecording.requestAccess()
                    }
                }

                Toggle("Hide Loop until direction is chosen", isOn: $hideUntilDirectionIsChosen)

                Toggle("Haptic Feedback", isOn: $hapticFeedback)

                CrispValueAdjuster(
                    "Size Increment",
                    description: "Used in size adjustment window actions",
                    value: $sizeIncrement,
                    sliderRange: 5...50,
                    postscript: "px",
                    step: 4.5,
                    lowerClamp: true
                )
            }

            Section(content: {
                HStack {
                    Text("Accessibility Access")
                    Spacer()
                    if isAccessibilityAccessGranted {
                        Text("Granted", comment: "When access to accessibility access is granted")
                    } else {
                        Text("Not Granted", comment: "When access to accessibility access not granted")
                    }
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
                        if isScreenRecordingAccessGranted {
                            Text("Granted", comment: "When access to screen recording permissions are available")
                        } else {
                            Text("Not Granted", comment: "When access to screen recording permissions aren't available")
                        }
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
                        "Sending feedback will bring you to our \"New Issue\" GitHub page, " +
                        "where you can report a bug, request a feature & more!"
                    )
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
