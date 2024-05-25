//
//  BehaviorConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import SwiftUI
import Luminare
import Defaults
import ServiceManagement

struct BehaviorConfigurationView: View {
    @Default(.launchAtLogin) var launchAtLogin
    @Default(.hideMenuBarIcon) var hideMenuBarIcon
    @Default(.animationConfiguration) var animationConfiguration
    @Default(.windowSnapping) var windowSnapping
    @Default(.focusWindowOnResize) var focusWindowOnResize
    @Default(.restoreWindowFrameOnDrag) var restoreWindowFrameOnDrag
    @Default(.respectStageManager) var respectStageManager
    @Default(.stageStripSize) var stageStripSize

    // Fixes animation for  @Default(.resizeWindowUnderCursor)
    @State private var resizeWindowUnderCursor = Defaults[.resizeWindowUnderCursor]

    // Fixes animation for @Default(.enablePadding)
    @State private var enablePadding = Defaults[.enablePadding]

    @State var isPaddingConfigurationViewPresented = false

    var body: some View {
        LuminareSection("General") {
            LuminareToggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _ in
                    if launchAtLogin {
                        try? SMAppService().register()
                    } else {
                        try? SMAppService().unregister()
                    }
                }

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

            LuminareToggle(
                "Resize window under cursor",
                isOn: $resizeWindowUnderCursor.animation(.smooth(duration: 0.25))
            )
            .onChange(of: resizeWindowUnderCursor) { _ in
                Defaults[.resizeWindowUnderCursor] = resizeWindowUnderCursor
            }

            if resizeWindowUnderCursor {
                LuminareToggle("Focus window on resize", isOn: $focusWindowOnResize)
            }

            LuminareToggle("Restore window frame on drag", isOn: $restoreWindowFrameOnDrag)

            LuminareToggle("Include padding", isOn: $enablePadding.animation(.smooth(duration: 0.25)))
                .onChange(of: enablePadding) { _ in
                    Defaults[.enablePadding] = enablePadding
                }

            if enablePadding {
                Button("Configure padding...") {
                    isPaddingConfigurationViewPresented = true
                }
                .luminareModal(isPresented: $isPaddingConfigurationViewPresented) {
                    PaddingConfigurationView(isPresented: $isPaddingConfigurationViewPresented)
                }
            }
        }

        LuminareSection("Stage Manager") {
            // TODO: Animate
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
