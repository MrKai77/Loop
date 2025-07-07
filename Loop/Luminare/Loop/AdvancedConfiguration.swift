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
    @Published var didImportSuccessfullyAlert = false
    @Published var didExportSuccessfullyAlert = false
    @Published var didResetSuccessfullyAlert = false

    @Published var isAccessibilityAccessGranted = AccessibilityManager.getStatus()
    @Published var accessibilityChecker: Publishers.Autoconnect<Timer.TimerPublisher> = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @Published var accessibilityChecks: Int = 0

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

    @StateObject private var model = AdvancedConfigurationModel()

    @Default(.useSystemWindowManagerWhenAvailable) var useSystemWindowManagerWhenAvailable
    @Default(.animateWindowResizes) var animateWindowResizes
    @Default(.hideUntilDirectionIsChosen) var hideUntilDirectionIsChosen
    @Default(.disableCursorInteraction) var disableCursorInteraction
    @Default(.ignoreFullscreen) var ignoreFullscreen
    @Default(.hapticFeedback) var hapticFeedback
    @Default(.sizeIncrement) var sizeIncrement

    let elementHeight: CGFloat = 34

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
                    .luminarePopover(attachedTo: .topTrailing) {
                        Text("This feature is still under development.")
                            .padding(4)
                    }
                    .tint(.orange)
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
        LuminareButton {
            HStack {
                if model.isAccessibilityAccessGranted {
                    Image(.badgeCheck2)
                        .foregroundStyle(tint)
                }

                Text("Accessibility access")
            }
        } content: {
            Text("Request…")
        } action: {
            model.beginAccessibilityAccessRequest()
        }
        .disabled(model.isAccessibilityAccessGranted)
    }
}
