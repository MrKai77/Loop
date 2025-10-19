//
//  AdvancedConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-26.
//

import Combine
import Defaults
import Luminare
import OSLog
import SwiftUI

final class AdvancedConfigurationModel: ObservableObject {
    private let logger = Logger(category: "AdvancedConfigurationModel")

    @Published private(set) var didImportSuccessfullyAlert = false
    @Published private(set) var didExportSuccessfullyAlert = false
    @Published private(set) var didResetSuccessfullyAlert = false

    @Published private(set) var isLowPowerModeEnabled: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Published private(set) var isAccessibilityAccessGranted = AccessibilityManager.shared.isGranted

    private var lowPowerModeCheckerTask: Task<(), Never>?
    private var accessibilityCheckerTask: Task<(), Never>?

    func startTracking() {
        trackLowPowerMode()
        trackAccessibilityStatus()
    }

    func stopTracking() {
        lowPowerModeCheckerTask?.cancel()
        accessibilityCheckerTask?.cancel()
    }

    private func trackLowPowerMode() {
        lowPowerModeCheckerTask = Task(priority: .background) {
            let notifications = NotificationCenter.default
                .notifications(named: Notification.Name.NSProcessInfoPowerStateDidChange)

            for await info in notifications {
                guard !Task.isCancelled else { break }
                guard let processInfo = info.object as? ProcessInfo else { continue }

                await MainActor.run {
                    isLowPowerModeEnabled = processInfo.isLowPowerModeEnabled
                }
            }
        }
    }

    private func trackAccessibilityStatus() {
        accessibilityCheckerTask = Task(priority: .background) {
            for await status in AccessibilityManager.shared.stream(initial: true) {
                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    isAccessibilityAccessGranted = status
                }
            }
        }
    }

    /// Prompts the user to import keybinds from a file.
    func importPrompt() {
        Task {
            do {
                try await Migrator.importPrompt(onSuccess: importedSuccessfully)
            } catch {
                logger.error("Error importing keybinds: \(error)")
            }
        }
    }

    /// Prompts the user to export keybinds to a file.
    func exportPrompt() {
        Task {
            do {
                try await Migrator.exportPrompt(onSuccess: exportedSuccessfully)
            } catch {
                logger.error("Error exporting keybinds: \(error)")
            }
        }
    }

    /// Resets keybinds to default values.
    func reset() {
        Defaults.reset(.keybinds)
        resetSuccessfully()
    }

    private func importedSuccessfully() {
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

    private func exportedSuccessfully() {
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

    private func resetSuccessfully() {
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
        generalSection
        keybindsSection
        permissionsSection
            .onAppear(perform: model.startTracking)
            .onDisappear(perform: model.stopTracking)
    }

    private var generalSection: some View {
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
                clampsUpper: false,
                suffix: Text("px")
            )
        }
    }

    private var keybindsSection: some View {
        LuminareSection("Keybinds") {
            HStack(spacing: 2) {
                Button(action: model.importPrompt) {
                    HStack {
                        Text("Import")

                        if model.didImportSuccessfullyAlert {
                            Image(systemName: "checkmark")
                                .foregroundStyle(tint)
                                .bold()
                        }
                    }
                }

                Button(action: model.exportPrompt) {
                    HStack {
                        Text("Export")

                        if model.didExportSuccessfullyAlert {
                            Image(systemName: "checkmark")
                                .foregroundStyle(tint)
                                .bold()
                        }
                    }
                }

                Button(role: .destructive, action: model.reset) {
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

    private var permissionsSection: some View {
        LuminareSection("Permissions") {
            accessibilityComponent()
        }
        .animation(luminareAnimation, value: model.isAccessibilityAccessGranted)
    }

    private func accessibilityComponent() -> some View {
        LuminareCompose {
            Button {
                AccessibilityManager.requestAccess()
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
