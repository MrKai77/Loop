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
    @Default(.hapticFeedback) var hapticFeedback

    var body: some View {
        LuminareSection("General") {
            LuminareToggle("Animate window resize", isOn: $animateWindowResizes)
            LuminareToggle("Hide until direction is chosen", isOn: $hideUntilDirectionIsChosen)
            LuminareToggle("Haptic feedback", isOn: $hapticFeedback)
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
