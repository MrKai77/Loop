//
//  BehaviorConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import Defaults
import Luminare
import ServiceManagement
import SwiftUI

//    let systemSnappingWarning: LuminareInfoView = .init("macOS's \"Tile by dragging windows to screen edges\" feature is currently\nenabled, which will conflict with Loop's window snapping functionality.")

struct BehaviorConfigurationView: View {
    @Default(.launchAtLogin) var launchAtLogin
    @Default(.hideMenuBarIcon) var hideMenuBarIcon
    @Default(.animationConfiguration) var animationConfiguration
    @Default(.windowSnapping) var windowSnapping
    @Default(.restoreWindowFrameOnDrag) var restoreWindowFrameOnDrag
    @Default(.useSystemWindowManagerWhenAvailable) var useSystemWindowManagerWhenAvailable
    @Default(.enablePadding) var enablePadding
    @Default(.useScreenWithCursor) var useScreenWithCursor
    @Default(.moveCursorWithWindow) var moveCursorWithWindow
    @Default(.resizeWindowUnderCursor) var resizeWindowUnderCursor
    @Default(.focusWindowOnResize) var focusWindowOnResize
    @Default(.respectStageManager) var respectStageManager
    @Default(.stageStripSize) var stageStripSize
    @Default(.previewVisibility) var previewVisibility

    @State private var isPaddingConfigurationViewPresented = false

    var body: some View {
        LuminareSection("General") {
            LuminareToggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _ in
                    do {
                        if launchAtLogin {
                            try SMAppService().register()
                        } else {
                            try SMAppService().unregister()
                        }
                    } catch {
                        print("Failed to \(launchAtLogin ? "register" : "unregister") login item: \(error.localizedDescription)")
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
            LuminareToggle("Move window to cursor's screen", isOn: $useScreenWithCursor)

            if #available(macOS 15, *) {
                LuminareToggle(
                    "Window snapping",
//                    info: SystemWindowManager.MoveAndResize.snappingEnabled ? systemSnappingWarning : nil, // TODO: Fix this
                    isOn: $windowSnapping
                )
            } else {
                LuminareToggle("Window snapping", isOn: $windowSnapping)
            }

            // Enabling the system window manager will override these options anyway, so hide them
            if !useSystemWindowManagerWhenAvailable {
                LuminareToggle("Restore window frame on drag", isOn: $restoreWindowFrameOnDrag)
                LuminareToggle("Apply padding", isOn: $enablePadding)

                if enablePadding {
                    Button("Configure padding…") {
                        isPaddingConfigurationViewPresented = true
                    }
                    .luminareModal(isPresented: $isPaddingConfigurationViewPresented) {
                        PaddingConfigurationView(isPresented: $isPaddingConfigurationViewPresented)
                            .frame(width: 400)
                    }
                }
            }
        }

        LuminareSection("Cursor") {
            LuminareToggle(
                "Move cursor with window",
//                info: previewVisibility ? nil : .init("Cannot be enabled when the preview is disabled."), // TODO: Fix this
                isOn: $moveCursorWithWindow
            )
            .disabled(!previewVisibility)

            LuminareToggle("Resize window under cursor", isOn: $resizeWindowUnderCursor)

            if resizeWindowUnderCursor {
                LuminareToggle("Focus window on resize", isOn: $focusWindowOnResize)
            }
        }

        LuminareSection("Stage Manager") {
            LuminareToggle("Respect Stage Manager", isOn: $respectStageManager)

            if respectStageManager {
                LuminareSlider(
                    "Stage strip size",
                    value: $stageStripSize.doubleBinding,
                    in: 50...200,
                    clampsLower: true,
                    suffix: "px"
                )
            }
        }
    }
}
