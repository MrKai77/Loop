//
//  AccentColorConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import Defaults
import Luminare
import SwiftUI

class AccentColorConfigurationModel: ObservableObject {
    // MARK: - Defaults

    @Published var useSystemAccentColor = Defaults[.useSystemAccentColor] {
        didSet { Defaults[.useSystemAccentColor] = useSystemAccentColor }
    }

    @Published var useGradient = Defaults[.useGradient] {
        didSet { Defaults[.useGradient] = useGradient }
    }

    @Published var customAccentColor = Defaults[.customAccentColor] {
        didSet { Defaults[.customAccentColor] = customAccentColor }
    }

    @Published var gradientColor = Defaults[.gradientColor] {
        didSet { Defaults[.gradientColor] = gradientColor }
    }

    @Published var processWallpaper = Defaults[.processWallpaper] {
        didSet {
            Defaults[.processWallpaper] = processWallpaper

            if processWallpaper {
                syncWallpaper()
            }
        }
    }

    func syncWallpaper() {
        Task {
            await WallpaperProcessor.fetchLatestWallpaperColors()

            await MainActor.run {
                withAnimation(LuminareSettingsWindow.fastAnimation) {
                    customAccentColor = Defaults[.customAccentColor]
                    gradientColor = Defaults[.gradientColor]
                }
            }

            // Force-rerender accent colors
            let window = LuminareManager.luminare
            await window?.resignMain()
            await window?.makeKeyAndOrderFront(self)
        }
    }
}

// MARK: - View

struct AccentColorConfigurationView: View {
    @StateObject private var model = AccentColorConfigurationModel()

    var body: some View {
        LuminareSection {
            LuminarePicker(
                elements: ["System", "Wallpaper", "Custom"],
                selection: $model.accentColorOption.animation(LuminareSettingsWindow.animation),
                columns: 3,
                roundBottom: model.useSystemAccentColor
            ) { option in
                VStack(spacing: 6) {
                    Spacer()
                    model.image(for: option)
                    Text(option)
                    Spacer()
                }
                .font(.title3)
                .frame(height: 90)
            }

            if model.isCustom || model.isWallpaper {
                LuminareToggle("Gradient", isOn: $model.useGradient.animation(LuminareSettingsWindow.animation))
            }

            if model.processWallpaper {
                Button("Sync Wallpaper") {
                    model.syncWallpaper()
                }
            }
        }

        VStack {
            if model.isCustom {
                HStack {
                    Text("Color")
                    Spacer()
                }
                .foregroundStyle(.secondary)

                LuminareColorPicker(
                    color: $model.customAccentColor,
                    colorNames: (red: "Red", green: "Green", blue: "Blue")
                )

                if model.useGradient {
                    LuminareColorPicker(
                        color: $model.gradientColor,
                        colorNames: (red: "Red", green: "Green", blue: "Blue")
                    )
                }
            }
        }
    }
}

// MARK: - View Extension

extension AccentColorConfigurationModel {
    var isCustom: Bool {
        useSystemAccentColor ? false : !processWallpaper
    }

    var isWallpaper: Bool {
        processWallpaper && !useSystemAccentColor
    }

    var accentColorOption: String {
        get {
            useSystemAccentColor ? "System" : (processWallpaper ? "Wallpaper" : "Custom")
        }
        set {
            useSystemAccentColor = newValue == "System"
            processWallpaper = newValue == "Wallpaper"
        }
    }

    func image(for option: String) -> Image {
        let imageNames = [
            "System": Image(systemName: "apple.logo"),
            "Wallpaper": Image(._18PxImageDepth),
            "Custom": Image(._18PxColorPalette)
        ]
        return imageNames[option] ?? Image(systemName: "exclamationmark.triangle")
    }
}
