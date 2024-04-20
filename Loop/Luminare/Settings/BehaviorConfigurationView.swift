//
//  BehaviorConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import SwiftUI
import Luminare
import Defaults

struct BehaviorConfigurationView: View {
    @Default(.launchAtLogin) var launchAtLogin
    @Default(.hideMenuBarIcon) var hideMenuBarIcon
    @Default(.animationConfiguration) var animationConfiguration
    @Default(.windowSnapping) var windowSnapping
    @Default(.resizeWindowUnderCursor) var resizeWindowUnderCursor
    @Default(.restoreWindowFrameOnDrag) var restoreWindowFrameOnDrag
    @Default(.enablePadding) var enablePadding
    @Default(.respectStageManager) var respectStageManager
    @Default(.stageStripSize) var stageStripSize

    var body: some View {
        LuminareSection("General") {
            LuminareToggle("Launch at login", isOn: $launchAtLogin)
            LuminareToggle("Hide menu bar icon", isOn: $hideMenuBarIcon)
            LuminareSliderPicker(
                "Animation speed",
                AnimationConfiguration.allCases.reversed(),
                selection: $animationConfiguration
            ) {
                $0.name
            }
        }

        LuminareSection("Window") {
            LuminareToggle("Window snapping", isOn: $windowSnapping)
            LuminareToggle("Resize window under cursor", isOn: $resizeWindowUnderCursor)
            LuminareToggle("Restore window frame on drag", isOn: $restoreWindowFrameOnDrag)

            LuminareToggle("Include padding", isOn: $enablePadding)

            if enablePadding {
                Button("Configure padding...") {
                    let modal = LuminareModalWindow(PaddingConfigurationView())
                    modal.show()
                }
            }
        }

        LuminareSection("Stage Manager") {
            LuminareToggle("Respect Stage Manager", isOn: $respectStageManager)

            if respectStageManager {
                LuminareValueAdjuster(
                    "Stage strip size",
                    value: $stageStripSize,
                    sliderRange: 50...200,
                    suffix: "px",
                    lowerClamp: true
                )
            }
        }
    }
}
