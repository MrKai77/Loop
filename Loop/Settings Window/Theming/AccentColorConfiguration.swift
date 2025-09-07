//
//  AccentColorConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import Defaults
import Luminare
import SwiftUI

// MARK: - View

struct AccentColorConfigurationView: View {
    @Environment(\.luminareAnimation) private var luminareAnimation
    @ObservedObject private var accentColorController: AccentColorController = .shared

    @Default(.accentColorMode) private var accentColorMode
    @Default(.useGradient) private var useGradient
    @Default(.customAccentColor) private var customAccentColor
    @Default(.gradientColor) private var gradientColor

    var body: some View {
        LuminareSection {
            LuminarePicker(
                elements: AccentColorOption.allCases,
                selection: $accentColorMode.animation(luminareAnimation),
                columns: 3
            ) { option in
                VStack(spacing: 6) {
                    Spacer()

                    option.image
                    Text(option.text)

                    Spacer()
                }
                .font(.title3)
                .frame(height: 90)
            }
            .luminarePickerRoundedCorner(top: .always)

            LuminareToggle("Gradient", isOn: $useGradient.animation(luminareAnimation))

            if accentColorMode == .wallpaper {
                Button("Sync Wallpaper") {
                    syncWallpaper()
                }
            }
        }

        VStack {
            if accentColorMode == .custom {
                HStack {
                    Text("Color")
                    Spacer()
                }
                .foregroundStyle(.secondary)

                LuminareColorPicker(
                    color: $customAccentColor,
                    style: .textFieldWithColorWell()
                )
                .luminareAspectRatio(contentMode: .fill)
                .luminareSheetClosesOnDefocus()

                if useGradient {
                    LuminareColorPicker(
                        color: $gradientColor,
                        style: .textFieldWithColorWell()
                    )
                    .luminareAspectRatio(contentMode: .fill)
                    .luminareSheetClosesOnDefocus()
                }
            }
        }
    }

    func syncWallpaper() {
        Task {
            await accentColorController.refresh()

            // Force-rerender accent colors
            let window = LuminareManager.shared.window
            window?.resignMain()
            window?.makeKeyAndOrderFront(self)
        }
    }
}
