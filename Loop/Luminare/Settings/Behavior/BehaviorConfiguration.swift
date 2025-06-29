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
            ) { item in
                Text(item.name)
                    .monospaced()
            }
        }

        LuminareSection("Window") {
            LuminareToggle("Move window to cursor's screen", isOn: $useScreenWithCursor)

            if #available(macOS 15, *) {
                LuminareToggle(isOn: $windowSnapping) {
                    if SystemWindowManager.MoveAndResize.snappingEnabled {
                        Text("Window snapping")
                            .luminarePopover(attachedTo: .topTrailing) {
                                Text("macOS's \"Tile by dragging windows to screen edges\" feature is currently\nenabled, which will conflict with Loop's window snapping functionality.")
                                    .padding()
                            }
                    } else {
                        Text("Window snapping")
                    }
                }
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
                    .luminareModalWithPredefinedSheetStyle(isPresented: $isPaddingConfigurationViewPresented, isCompact: false) {
                        PaddingConfigurationView(isPresented: $isPaddingConfigurationViewPresented)
                            .frame(width: 400)
                    }
                }
            }
        }
        .onReceive(.systemWindowManagerStateChanged) { _ in
            model.useSystemWindowManagerWhenAvailable = Defaults[.useSystemWindowManagerWhenAvailable]
        }
        .onChange(of: model.stashedWindowVisiblePadding) { _ in
            AppDelegate.stashManager.onConfigurationChanged()
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
                    format: .number.precision(.fractionLength(0...0)),
                    clampsLower: true,
                    suffix: Text("px")
                )
            }
        }

        LuminareSection("Stash") {
            LuminareToggle("Animated", isOn: $model.animateStashedWindows)
            LuminareValueAdjuster(
                "Peek size",
                value: $model.stashedWindowVisiblePadding,
                sliderRange: 1...200,
                suffix: "px",
                lowerClamp: true
            )
            LuminareToggle("Shift focus when stashed", isOn: $model.shiftFocusWhenStashed)
        }
    }
}
