//
//  BehaviorConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import Defaults
import Luminare
import OSLog
import ServiceManagement
import SwiftUI

struct BehaviorConfigurationView: View {
    @Environment(\.luminareAnimation) private var luminareAnimation
    private static let logger = Logger(category: "BehaviorConfigurationView")

    @Default(.launchAtLogin) var launchAtLogin
    @Default(.hideMenuBarIcon) var hideMenuBarIcon
    @Default(.animationConfiguration) var animationConfiguration
    @Default(.windowSnapping) var windowSnapping
    @Default(.suppressMissionControlOnTopDrag) var suppressMissionControlOnTopDrag
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
    @Default(.stashedWindowVisiblePadding) var stashedWindowVisiblePadding
    @Default(.animateStashedWindows) var animateStashedWindows
    @Default(.shiftFocusWhenStashed) var shiftFocusWhenStashed

    @State private var isPaddingConfigurationViewPresented = false

    var body: some View {
        Group {
            generalSection
            windowSection
            cursorSection
            windowSnappingSection
            stageManagerSection
            stashSection
        }
        .animation(
            luminareAnimation,
            value: [
                enablePadding,
                resizeWindowUnderCursor,
                windowSnapping,
                respectStageManager
            ]
        )
    }

    private var generalSection: some View {
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
                        Self.logger.error("Failed to \(launchAtLogin ? "register" : "unregister") login item: \(error.localizedDescription)")
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
    }

    private var windowSection: some View {
        LuminareSection("Window") {
            LuminareToggle("Move window to cursor's screen", isOn: $useScreenWithCursor)

            // Enabling the system window manager will override these options.
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
    }

    private var cursorSection: some View {
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
    }

    private var windowSnappingSection: some View {
        LuminareSection("Window Snapping") {
            if #available(macOS 15, *) {
                LuminareToggle(isOn: $windowSnapping) {
                    if SystemWindowManager.MoveAndResize.snappingEnabled {
                        Text("Enable window snapping")
                            .padding(.trailing, 4)
                            .luminarePopover(attachedTo: .topTrailing) {
                                Text("macOS's \"Tile by dragging windows to screen edges\" feature is currently\nenabled, which will conflict with Loop's window snapping functionality.")
                                    .padding(6)
                            }
                    } else {
                        Text("Enable window snapping")
                    }
                }
            } else {
                LuminareToggle("Enable window snapping", isOn: $windowSnapping)
            }

            if windowSnapping {
                LuminareToggle(isOn: $suppressMissionControlOnTopDrag) {
                    Text("Suppress Mission Control")
                        .padding(.trailing, 4)
                        .luminarePopover(attachedTo: .topTrailing) {
                            Text("Whether to allow Mission Control to open when windows\nare dragged to the top of the screen.")
                                .padding(6)
                        }
                }
            }
        }
    }

    private var stageManagerSection: some View {
        LuminareSection("Stage Manager") {
            LuminareToggle("Respect Stage Manager", isOn: $respectStageManager)

            if respectStageManager {
                LuminareSlider(
                    "Stage strip size",
                    value: $stageStripSize.doubleBinding,
                    in: 50...250,
                    format: .number.precision(.fractionLength(0...0)),
                    clampsUpper: false,
                    suffix: Text("px")
                )
            }
        }
    }

    private var stashSection: some View {
        LuminareSection("Stash") {
            LuminareToggle("Animated", isOn: $animateStashedWindows)

            LuminareSlider(
                "Peek size",
                value: $stashedWindowVisiblePadding.doubleBinding,
                in: 1...200,
                format: .number.precision(.fractionLength(0...0)),
                clampsUpper: false,
                suffix: Text("px")
            )

            LuminareToggle("Shift focus when stashed", isOn: $shiftFocusWhenStashed)
        }
        .onChange(of: stashedWindowVisiblePadding) { _ in
            StashManager.shared.onConfigurationChanged()
        }
    }
}
