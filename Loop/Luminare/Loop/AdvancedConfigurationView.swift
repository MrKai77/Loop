//
//  AdvancedConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-26.
//

import SwiftUI
import Luminare
import Defaults

struct AdvancedConfigurationView: View {
    @Default(.animateWindowResizes) var animateWindowResizes
    @Default(.hideUntilDirectionIsChosen) var hideUntilDirectionIsChosen
    @Default(.disableCursorInteraction) var disableCursorInteraction
    @Default(.hapticFeedback) var hapticFeedback
    @Default(.sizeIncrement) var sizeIncrement

    @State var isAccessibilityAccessGranted = false
    let elementHeight: CGFloat = 34

    var body: some View {
        LuminareSection("General") {
            LuminareToggle("Animate window resize", isOn: $animateWindowResizes)
            LuminareToggle("Disable radial menu cursor interaction", isOn: $disableCursorInteraction)
            LuminareToggle("Hide until direction is chosen", isOn: $hideUntilDirectionIsChosen)
            LuminareToggle("Haptic feedback", isOn: $hapticFeedback)

            LuminareValueAdjuster(
                "Size increment",   // Description: Used in size adjustment window actions
                value: $sizeIncrement,
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
                if isAccessibilityAccessGranted {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green.pastelized)
                }

                Text("Accessibility access")

                Spacer()

                Button {
                    withAnimation(.smooth) {
                        isAccessibilityAccessGranted = AccessibilityManager.requestAccess()
                    }
                } label: {
                    Text("Request…")
                        .frame(height: 30)
                        .padding(.horizontal, 8)
                }
                .disabled(isAccessibilityAccessGranted)
                .buttonStyle(LuminareCompactButtonStyle(extraCompact: true))
            }
            .padding(.leading, 8)
            .padding(.trailing, 2)
            .frame(height: elementHeight)
        }
        .onAppear {
            isAccessibilityAccessGranted = AccessibilityManager.getStatus()
        }
    }
}
