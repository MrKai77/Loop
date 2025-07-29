//
//  AccentColorConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import Defaults
import Luminare
import SwiftUI

// MARK: - AccentColorOption

enum AccentColorOption: CaseIterable {
    case system
    case wallpaper
    case custom

    var image: Image {
        switch self {
        case .system: Image(systemName: "apple.logo")
        case .wallpaper: Image(.imageDepth)
        case .custom: Image(.colorPalette)
        }
    }

    var text: String {
        switch self {
        case .system: .init(localized: "Accent color option: System", defaultValue: "System")
        case .wallpaper: .init(localized: "Accent color option: Wallpaper", defaultValue: "Wallpaper")
        case .custom: .init(localized: "Accent color option: Custom", defaultValue: "Custom")
        }
    }
}

// MARK: - View

struct AccentColorConfigurationView: View {
    @Environment(\.luminareAnimation) private var luminareAnimation

    @Default(.useSystemAccentColor) private var useSystemAccentColor
    @Default(.useGradient) private var useGradient
    @Default(.customAccentColor) private var customAccentColor
    @Default(.gradientColor) private var gradientColor
    @Default(.processWallpaper) private var processWallpaper

    var isCustom: Bool {
        useSystemAccentColor ? false : !processWallpaper
    }

    var isWallpaper: Bool {
        processWallpaper && !useSystemAccentColor
    }

    var accentColorOption: Binding<AccentColorOption> {
        Binding(
            get: {
                useSystemAccentColor ? .system : (processWallpaper ? .wallpaper : .custom)
            },
            set: { newValue in
                useSystemAccentColor = newValue == .system
                processWallpaper = newValue == .wallpaper
            }
        )
    }

    var body: some View {
        LuminareSection {
            LuminarePicker(
                elements: AccentColorOption.allCases,
                selection: accentColorOption.animation(luminareAnimation),
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

            if processWallpaper {
                Button("Sync Wallpaper") {
                    syncWallpaper()
                }
            }
        }

        VStack {
            if isCustom {
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
            await WallpaperProcessor.fetchLatest(ignoreThrottle: true)

            await MainActor.run {
                withAnimation(luminareAnimation) {
                    customAccentColor = Defaults[.customAccentColor]
                    gradientColor = Defaults[.gradientColor]
                }
            }

            // Force-rerender accent colors
            let window = LuminareManager.shared.luminare
            window?.resignMain()
            window?.makeKeyAndOrderFront(self)
        }
    }
}
