//
//  AdvancedConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-26.
//

import Combine
import Defaults
import Luminare
import SwiftUI

class AdvancedConfigurationModel: ObservableObject {
    @Published var useSystemWindowManagerWhenAvailable = Defaults[.useSystemWindowManagerWhenAvailable] {
        didSet { Defaults[.useSystemWindowManagerWhenAvailable] = useSystemWindowManagerWhenAvailable }
    }

    @Published var animateWindowResizes = Defaults[.animateWindowResizes] {
        didSet { Defaults[.animateWindowResizes] = animateWindowResizes }
    }

    @Published var hideUntilDirectionIsChosen = Defaults[.hideUntilDirectionIsChosen] {
        didSet { Defaults[.hideUntilDirectionIsChosen] = hideUntilDirectionIsChosen }
    }

    @Published var disableCursorInteraction = Defaults[.disableCursorInteraction] {
        didSet { Defaults[.disableCursorInteraction] = disableCursorInteraction }
    }

    @Published var ignoreFullscreen = Defaults[.ignoreFullscreen] {
        didSet { Defaults[.ignoreFullscreen] = ignoreFullscreen }
    }

    @Published var hapticFeedback = Defaults[.hapticFeedback] {
        didSet { Defaults[.hapticFeedback] = hapticFeedback }
    }

    @Published var sizeIncrement = Defaults[.sizeIncrement] {
        didSet { Defaults[.sizeIncrement] = sizeIncrement }
    }

    @Published var isAccessibilityAccessGranted = AccessibilityManager.getStatus()
    @Published var isScreenCaptureAccessGranted = ScreenCaptureManager.getStatus()
    @Published var accessibilityChecker: Publishers.Autoconnect<Timer.TimerPublisher> = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @Published var accessibilityChecks: Int = 0

    func beginAccessibilityAccessRequest() {
        accessibilityChecker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        accessibilityChecks = 0
        AccessibilityManager.requestAccess()
    }

    // No point in checking for screen capture permits since that REQUIRES a relaunch, unfortunately
    func refreshAccessiblityStatus() {
        accessibilityChecks += 1
        let isAccessibilityGranted = AccessibilityManager.getStatus()

        if isAccessibilityAccessGranted != isAccessibilityGranted {
            withAnimation(LuminareSettingsWindow.animation) {
                isAccessibilityAccessGranted = isAccessibilityGranted
            }
        }

        if isAccessibilityGranted || accessibilityChecks > 60 {
            accessibilityChecker.upstream.connect().cancel()
        }
    }
}

struct AdvancedConfigurationView: View {
    @Environment(\.tintColor) var tintColor
    @StateObject private var model = AdvancedConfigurationModel()
    let elementHeight: CGFloat = 34

    var body: some View {
        LuminareSection("General") {
            if #available(macOS 15.0, *) {
                LuminareToggle("Use macOS window manager when available", isOn: $model.useSystemWindowManagerWhenAvailable)
            }
            LuminareToggle(
                "Animate window resize",
                info: .init("This feature is still under development.", .orange),
                isOn: $model.animateWindowResizes
            )
            LuminareToggle("Disable cursor interaction", isOn: $model.disableCursorInteraction)
            LuminareToggle("Ignore fullscreen windows", isOn: $model.ignoreFullscreen)
            LuminareToggle("Hide until direction is chosen", isOn: $model.hideUntilDirectionIsChosen)
            LuminareToggle("Haptic feedback", isOn: $model.hapticFeedback)

            LuminareValueAdjuster(
                "Size increment", // Description: Used in size adjustment window actions
                value: $model.sizeIncrement,
                sliderRange: 5...50,
                suffix: "px",
                step: 4.5,
                lowerClamp: true
            )
        }

        LuminareSection("Keybinds") {
            HStack(spacing: 2) {
                Button("Import") {
                    WindowAction.importPrompt()
                }

                Button("Export") {
                    WindowAction.exportPrompt()
                }

                Button("Reset") {
                    Defaults.reset(.keybinds)
                }
                .buttonStyle(LuminareDestructiveButtonStyle())
            }
        }

        LuminareSection {
            Button("Import keybinds from Rectangle") {
                RectangleTranslationLayer.initiateImportProcess()
            }
            .buttonStyle(LuminareButtonStyle())
        }

        LuminareSection("Permissions") {
            accessibilityComponent()
            screenCaptureComponent()
        }
        .onReceive(model.accessibilityChecker) { _ in
            model.refreshAccessiblityStatus()
        }
    }

    func accessibilityComponent() -> some View {
        HStack {
            if model.isAccessibilityAccessGranted {
                Image(._18PxBadgeCheck2)
                    .foregroundStyle(tintColor())
            }

            Text("Accessibility access")

            Spacer()

            Button {
                model.beginAccessibilityAccessRequest()
            } label: {
                Text("Request…")
                    .frame(height: 30)
                    .padding(.horizontal, 8)
            }
            .disabled(model.isAccessibilityAccessGranted)
            .buttonStyle(LuminareCompactButtonStyle(extraCompact: true))
        }
        .padding(.leading, 8)
        .padding(.trailing, 2)
        .frame(height: elementHeight)
    }

    func screenCaptureComponent() -> some View {
        HStack {
            if model.isScreenCaptureAccessGranted {
                Image(._18PxBadgeCheck2)
                    .foregroundStyle(tintColor())
            }

            Text("Screen capture access")

            Spacer()

            Button {
                ScreenCaptureManager.requestAccess()
            } label: {
                Text("Request…")
                    .frame(height: 30)
                    .padding(.horizontal, 8)
            }
            .disabled(model.isScreenCaptureAccessGranted)
            .buttonStyle(LuminareCompactButtonStyle(extraCompact: true))
        }
        .padding(.leading, 8)
        .padding(.trailing, 2)
        .frame(height: elementHeight)
    }
}
