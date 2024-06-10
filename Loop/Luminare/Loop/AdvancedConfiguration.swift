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
    @Published var animateWindowResizes = Defaults[.animateWindowResizes] {
        didSet {
            Defaults[.animateWindowResizes] = animateWindowResizes
        }
    }

    @Published var hideUntilDirectionIsChosen = Defaults[.hideUntilDirectionIsChosen] {
        didSet {
            Defaults[.hideUntilDirectionIsChosen] = hideUntilDirectionIsChosen
        }
    }

    @Published var disableCursorInteraction = Defaults[.disableCursorInteraction] {
        didSet {
            Defaults[.disableCursorInteraction] = disableCursorInteraction
        }
    }

    @Published var hapticFeedback = Defaults[.hapticFeedback] {
        didSet {
            Defaults[.hapticFeedback] = hapticFeedback
        }
    }

    @Published var sizeIncrement = Defaults[.sizeIncrement] {
        didSet {
            Defaults[.sizeIncrement] = sizeIncrement
        }
    }

    @Published var isAccessibilityAccessGranted = AccessibilityManager.getStatus()
    @Published var accessibilityChecker: Publishers.Autoconnect<Timer.TimerPublisher> = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @Published var accessibilityChecks: Int = 0

    func beginAccessibilityAccessRequest() {
        accessibilityChecker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        accessibilityChecks = 0
        AccessibilityManager.requestAccess()
    }

    func refreshAccessiblityStatus() {
        accessibilityChecks += 1
        let isGranted = AccessibilityManager.getStatus()

        if isAccessibilityAccessGranted != isGranted {
            withAnimation(.smooth) {
                isAccessibilityAccessGranted = isGranted
            }
        }

        if isGranted || accessibilityChecks > 60 {
            accessibilityChecker.upstream.connect().cancel()
        }
    }
}

struct AdvancedConfigurationView: View {
    @StateObject private var model = AdvancedConfigurationModel()
    let elementHeight: CGFloat = 34

    var body: some View {
        LuminareSection("General") {
            LuminareToggle(
                "Animate window resize",
                info: .init("This feature is still under development.", .orange),
                isOn: $model.animateWindowResizes
            )
            LuminareToggle("Disable radial menu cursor interaction", isOn: $model.disableCursorInteraction)
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

        LuminareSection("Permissions") {
            HStack {
                if model.isAccessibilityAccessGranted {
                    Image(._18PxBadgeCheck2)
                        .foregroundStyle(Color.getLoopAccent(tone: .normal))
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
        .onReceive(model.accessibilityChecker) { _ in
            model.refreshAccessiblityStatus()
        }
    }
}
