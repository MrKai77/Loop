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

    @Published private(set) var isLowPowerModeEnabled: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Published private(set) var isAccessibilityAccessGranted = AccessibilityManager.getStatus()

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
            while !Task.isCancelled {
                let isAccessibilityGranted = AccessibilityManager.getStatus()

                if isAccessibilityAccessGranted != isAccessibilityGranted {
                    await MainActor.run {
                        isAccessibilityAccessGranted = isAccessibilityGranted
                    }
                }

                try? await Task.sleep(for: .seconds(1))
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
            .onAppear(perform: model.startTracking)
            .onDisappear(perform: model.stopTracking)
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
        .animation(luminareAnimation, value: model.isAccessibilityAccessGranted)
    }

    func accessibilityComponent() -> some View {
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
