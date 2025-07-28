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
    @Published private(set) var didImportSuccessfullyAlert = false
    @Published private(set) var didExportSuccessfullyAlert = false
    @Published private(set) var didResetSuccessfullyAlert = false

    @Published private(set) var isAccessibilityAccessGranted = AccessibilityManager.getStatus()
    @Published private(set) var accessibilityChecker: Publishers.Autoconnect<Timer.TimerPublisher> = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @Published private(set) var accessibilityChecks: Int = 0

    @Published private(set) var isLowPowerModeEnabled: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled

    init() {
        trackLowPowerMode()
    }

    private func trackLowPowerMode() {
        Task {
            let notifications = NotificationCenter.default
                .notifications(named: Notification.Name.NSProcessInfoPowerStateDidChange)

            for await info in notifications {
                guard let processInfo = info.object as? ProcessInfo else { continue }

                await MainActor.run {
                    isLowPowerModeEnabled = processInfo.isLowPowerModeEnabled
                }
            }
        }
    }

    func importedSuccessfully() {
        DispatchQueue.main.async { [weak self] in
            withAnimation(.smooth(duration: 0.5)) {
                self?.didImportSuccessfullyAlert = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            withAnimation(.smooth(duration: 0.5)) {
                self?.didImportSuccessfullyAlert = false
            }
        }
    }

    func exportedSuccessfully() {
        DispatchQueue.main.async { [weak self] in
            withAnimation(.smooth(duration: 0.5)) {
                self?.didExportSuccessfullyAlert = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            withAnimation(.smooth(duration: 0.5)) {
                self?.didExportSuccessfullyAlert = false
            }
        }
    }

    func resetSuccessfully() {
        DispatchQueue.main.async { [weak self] in
            withAnimation(.smooth(duration: 0.5)) {
                self?.didResetSuccessfullyAlert = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            withAnimation(.smooth(duration: 0.5)) {
                self?.didResetSuccessfullyAlert = false
            }
        }
    }

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
            isAccessibilityAccessGranted = isAccessibilityGranted
        }

        if isAccessibilityGranted || accessibilityChecks > 60 {
            accessibilityChecker.upstream.connect().cancel()
        }
    }
}

struct AdvancedConfigurationView: View {
    @Environment(\.luminareTintColor) var tint
    @Environment(\.luminareAnimation) var luminareAnimation
    @Environment(\.openURL) private var openURL

    @StateObject private var model = AdvancedConfigurationModel()

    @Default(.useSystemWindowManagerWhenAvailable) var useSystemWindowManagerWhenAvailable
    @Default(.ignoreLowPowerMode) var ignoreLowPowerMode
    @Default(.animateWindowResizes) var animateWindowResizes
    @Default(.hideUntilDirectionIsChosen) var hideUntilDirectionIsChosen
    @Default(.disableCursorInteraction) var disableCursorInteraction
    @Default(.ignoreFullscreen) var ignoreFullscreen
    @Default(.hapticFeedback) var hapticFeedback
    @Default(.sizeIncrement) var sizeIncrement

    private var showLowPowerModeWarning: Bool {
        animateWindowResizes && !ignoreLowPowerMode && model.isLowPowerModeEnabled
    }

    var body: some View {
        generalSection()
        keybindsSection()
        permissionsSection()
    }

    func generalSection() -> some View {
        LuminareSection("General") {
            if #available(macOS 15.0, *) {
                LuminareToggle("Use macOS window manager when available", isOn: $useSystemWindowManagerWhenAvailable)
            }

            LuminareToggle(isOn: $animateWindowResizes) {
                Text("Animate window resize")
                    .padding(.trailing, 4)
                    .luminarePopover(attachedTo: .topTrailing, hidden: !showLowPowerModeWarning) {
                        HStack(spacing: 4) {
                            Text("To save power, window animations are\nunavailable in Low Power Mode.")
                                .multilineTextAlignment(.leading)

                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
                                Button {
                                    openURL(url)
                                } label: {
                                    Image(.shareUpRight)
                                        .foregroundStyle(.secondary)
                                        .padding(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(6)
                    }
                    .luminareTint(overridingWith: .yellow)
                    .animation(luminareAnimation, value: showLowPowerModeWarning)
            }

            LuminareToggle("Disable cursor interaction", isOn: $disableCursorInteraction)
            LuminareToggle("Ignore fullscreen windows", isOn: $ignoreFullscreen)
            LuminareToggle("Hide until direction is chosen", isOn: $hideUntilDirectionIsChosen)
            LuminareToggle("Haptic feedback", isOn: $hapticFeedback)

            LuminareSlider(
                "Size increment",
                value: $sizeIncrement.doubleBinding,
                in: 5...50,
                step: 4.5,
                format: .number.precision(.fractionLength(0...0)),
                clampsLower: true,
                suffix: Text("px")
            )
        }
    }

    func keybindsSection() -> some View {
        LuminareSection("Keybinds") {
            HStack(spacing: 2) {
                Button {
                    Task {
                        do {
                            try await Migrator.importPrompt()
                        } catch {
                            print("Error importing keybinds: \(error)")
                        }
                    }
                } label: {
                    HStack {
                        Text("Import")

                        if model.didImportSuccessfullyAlert {
                            Image(systemName: "checkmark")
                                .foregroundStyle(tint)
                                .bold()
                        }
                    }
                }
                .onReceive(.didImportKeybindsSuccessfully) { _ in
                    model.importedSuccessfully()
                }

                Button {
                    Task {
                        do {
                            try await Migrator.exportPrompt()
                        } catch {
                            print("Error exporting keybinds: \(error)")
                        }
                    }
                } label: {
                    HStack {
                        Text("Export")

                        if model.didExportSuccessfullyAlert {
                            Image(systemName: "checkmark")
                                .foregroundStyle(tint)
                                .bold()
                        }
                    }
                }
                .onReceive(.didExportKeybindsSuccessfully) { _ in
                    model.exportedSuccessfully()
                }

                Button(role: .destructive) {
                    Defaults.reset(.keybinds)
                    model.resetSuccessfully()
                } label: {
                    HStack {
                        Text("Reset")

                        if model.didResetSuccessfullyAlert {
                            Image(systemName: "checkmark")
                                .foregroundStyle(tint)
                                .bold()
                        }
                    }
                }
                .buttonStyle(.luminareProminent)
            }
        }
    }

    func permissionsSection() -> some View {
        LuminareSection("Permissions") {
            accessibilityComponent()
        }
        .onReceive(model.accessibilityChecker) { _ in
            model.refreshAccessiblityStatus()
        }
        .animation(luminareAnimation, value: model.isAccessibilityAccessGranted)
    }

    func accessibilityComponent() -> some View {
        LuminareCompose {
            Button {
                model.beginAccessibilityAccessRequest()
            } label: {
                Text("Request…")
            }
            .buttonStyle(.luminareCompact)
            .luminareComposeIgnoreSafeArea(edges: .trailing)
            .disabled(model.isAccessibilityAccessGranted)
        } label: {
            HStack {
                if model.isAccessibilityAccessGranted {
                    Image(.badgeCheck2)
                        .foregroundStyle(tint)
                }

                Text("Accessibility access")
            }
        }
        .luminareComposeStyle(.inline)
    }
}
