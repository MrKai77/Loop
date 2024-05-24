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

    var body: some View {
        Form {
            Section("Advanced") {
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
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}
