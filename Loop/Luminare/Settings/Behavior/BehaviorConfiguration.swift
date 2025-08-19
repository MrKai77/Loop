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
    @Environment(\.luminareAnimation) private var luminareAnimation

    @Default(.launchAtLogin) var launchAtLogin
    @Default(.hideMenuBarIcon) var hideMenuBarIcon
    @Default(.animationConfiguration) var animationConfiguration
    @Default(.windowSnapping) var windowSnapping
    @Default(.restoreWindowFrameOnDrag) var restoreWindowFrameOnDrag
    @Default(.useSystemWindowManagerWhenAvailable) var useSystemWindowManagerWhenAvailable
    @Default(.enablePadding) var enablePadding
    @Default(.cycleModeRestartEnabled) var cycleModeRestartEnabled
    @Default(.useScreenWithCursor) var useScreenWithCursor
    @Default(.moveCursorWithWindow) var moveCursorWithWindow
    @Default(.resizeWindowUnderCursor) var resizeWindowUnderCursor
    @Default(.focusWindowOnResize) var focusWindowOnResize
    @Default(.respectStageManager) var respectStageManager
    @Default(.stageStripSize) var stageStripSize
    @Default(.previewVisibility) var previewVisibility
    @Default(.stashedWindowVisiblePadding) var stashedWindowVisiblePadding
    @Default(.animateStashedWindows) var animateStashedWindows
    @Default(.shiftFocusWhenStashed) var shiftFocusWhenStashed

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
                            .padding(.trailing, 4)
                            .luminarePopover(attachedTo: .topTrailing) {
                                Text("macOS's \"Tile by dragging windows to screen edges\" feature is currently\nenabled, which will conflict with Loop's window snapping functionality.")
                                    .padding(6)
                            }
                    } else {
                        Text("Window snapping")
                    }
                }
            } else {
                LuminareToggle("Window snapping", isOn: $windowSnapping)
            }

            LuminareToggle("Cycle always start at first item", isOn: $cycleModeRestartEnabled)

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

        LuminareSection("Cursor") {
            // This can only be enabled when the preview is visible.
            // Because when the preview is disabled, the window moves live with cursor movement,
            // so moving the cursor would be unusable.
            if previewVisibility {
                LuminareToggle("Move cursor with window", isOn: $moveCursorWithWindow)
            }

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
            LuminareToggle("Animated", isOn: $animateStashedWindows)

            LuminareSlider(
                "Peek size",
                value: $stashedWindowVisiblePadding.doubleBinding,
                in: 1...200,
                format: .number.precision(.fractionLength(0...0)),
                clampsLower: true,
                suffix: Text("px")
            )

            LuminareToggle("Shift focus when stashed", isOn: $shiftFocusWhenStashed)
        }
        .onChange(of: stashedWindowVisiblePadding) { _ in
            AppDelegate.stashManager.onConfigurationChanged()
        }
    }
}
