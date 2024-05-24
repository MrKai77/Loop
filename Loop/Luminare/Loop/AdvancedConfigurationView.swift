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
    }
}
