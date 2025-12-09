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
    @Environment(\.luminareTintColor) var tint
    @Environment(\.luminareAnimation) private var luminareAnimation
    @ObservedObject private var accentColorController: AccentColorController = .shared

    @Default(.accentColorMode) private var accentColorMode
    @Default(.useGradient) private var useGradient
    @Default(.customAccentColor) private var customAccentColor
    @Default(.gradientColor) private var gradientColor

    @State private var didSyncWallpaper: Bool = false
    @State private var syncWallpaperTask: Task<(), Never>?

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
            .luminareRoundingBehavior(top: true)

            LuminareToggle("Gradient", isOn: $useGradient.animation(luminareAnimation))

            if accentColorMode == .wallpaper {
                Button(action: syncWallpaper) {
                    HStack {
                        Text("Sync Wallpaper")

                        if didSyncWallpaper {
                            Image(systemName: "checkmark")
                                .foregroundStyle(tint)
                                .bold()
                        }
                    }
                }
                .luminareRoundingBehavior(bottom: true)
            }
        }

        if accentColorMode == .custom {
            LuminareSection(String(localized: "Color", comment: "Section header shown in settings")) {
                LuminareColorPicker(
                    color: $customAccentColor,
                    style: .textFieldWithColorWell()
                )
                .luminareRoundingBehavior(top: true, bottom: true)

                if useGradient {
                    LuminareColorPicker(
                        color: $gradientColor,
                        style: .textFieldWithColorWell()
                    )
                    .luminareRoundingBehavior(top: true, bottom: true)
                }
            }
            .luminareSheetClosesOnDefocus()
        }
    }

    func syncWallpaper() {
        if syncWallpaperTask != nil {
            return
        }

        syncWallpaperTask = Task {
            await accentColorController.refresh()

            // Force-rerender accent colors
            let window = SettingsWindowManager.shared.window
            window?.resignMain()
            window?.makeKeyAndOrderFront(self)

            withAnimation(.smooth(duration: 0.5)) {
                didSyncWallpaper = true
            }

            try? await Task.sleep(for: .seconds(2))

            withAnimation(.smooth(duration: 0.5)) {
                didSyncWallpaper = false
            }

            syncWallpaperTask = nil
        }
    }
}
