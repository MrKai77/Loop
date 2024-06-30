//
//  AccentColorConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//
#warning("TODO: Connect the 'Dynamic Wallpaper Sync' to the timer to synchronize it as the button currently does.")

import Defaults
import Luminare
import SwiftUI

class AccentColorConfigurationModel: ObservableObject {
    @Published var useSystemAccentColor = Defaults[.useSystemAccentColor] {
        didSet {
            Defaults[.useSystemAccentColor] = useSystemAccentColor
        }
    }

    @Published var useGradient = Defaults[.useGradient] {
        didSet {
            Defaults[.useGradient] = useGradient
        }
    }

    @Published var customAccentColor = Defaults[.customAccentColor] {
        didSet {
            Defaults[.customAccentColor] = customAccentColor
        }
    }

    @Published var gradientColor = Defaults[.gradientColor] {
        didSet {
            Defaults[.gradientColor] = gradientColor
        }
    }

    @Published var processWallpaper = Defaults[.processWallpaper] {
        didSet {
            Defaults[.processWallpaper] = processWallpaper
            if processWallpaper {
                fetchWallpaperColors()
            }
        }
    }

    @Published var autoCheckWallpaper = Defaults[.autoCheckWallpaper] {
        didSet {
            Defaults[.autoCheckWallpaper] = autoCheckWallpaper
            handleAutoCheckWallpaperToggle(autoCheckWallpaper)
        }
    }

    private func handleAutoCheckWallpaperToggle(_ isOn: Bool) {
        if isOn {
            WallpaperProcessor.startAutoCheckWallpaperTimer()
        } else {
            WallpaperProcessor.stopAutoCheckWallpaperTimer()
        }
    }

    private func updateColorsFromWallpaper(with colors: [NSColor]) {
        DispatchQueue.main.async {
            self.customAccentColor = Color(colors.first ?? .clear)
            self.gradientColor = colors.count > 1 ? Color(colors[1]) : self.gradientColor
        }
    }

    func fetchWallpaperColors() {
        WallpaperProcessor.processCurrentWallpaper { [weak self] result in
            switch result {
            case let .success(colors):
                self?.updateColorsFromWallpaper(with: colors)
            case let .failure(error):
                print(error.localizedDescription)
            }
        }
    }
}

struct AccentColorConfigurationView: View {
    @StateObject private var model = AccentColorConfigurationModel()

    var body: some View {
        LuminareSection {
            LuminarePicker(
                elements: [true, false],
                selection: $model.useSystemAccentColor.animation(.smooth(duration: 0.25)),
                columns: 2,
                roundBottom: false
            ) { item in
                VStack {
                    Spacer()
                    Spacer()

                    if item {
                        Image(systemName: "apple.logo")
                    } else {
                        Image(._18PxColorPalette)
                    }

                    Spacer()

                    Text(item ? "System" : "Custom")

                    Spacer()
                    Spacer()
                }
                .font(.title3)
                .frame(height: 90)
            }

            LuminareToggle("Gradient", isOn: $model.useGradient.animation(.smooth(duration: 0.25)))
            LuminareToggle("Use Wallpaper Colors", isOn: $model.processWallpaper.animation(.smooth(duration: 0.25)))

            // Show the auto check toggle only if processWallpaper is true
            if model.processWallpaper {
                LuminareToggle("Dynamic Wallpaper Sync", isOn: $model.autoCheckWallpaper.animation(.smooth(duration: 0.25)))

                // Do we want a force wallpaper button like this in prod? who knows, i don't
                // It might be useful... Additionally, we should configure a custom timer in the advanced
                // options section to synchronize with the dynamic changes in the wallpaper section. So
                // 5s, 1m, 5m, 15m, 30m, 1h, 24h or more if we'd like, this is just sys defaults
                Button("Sync Wallpaper") {
                    model.fetchWallpaperColors()
                }
            }
        }

        VStack {
            // Show the color pickers when 'Use Wallpaper Colors' is toggled off
            if !model.useSystemAccentColor {
                HStack {
                    Text("Color")
                    Spacer()
                }
                .foregroundStyle(.secondary)

                LuminareColorPicker(color: $model.customAccentColor, colorNames: (red: "Red", green: "Green", blue: "Blue"))

                if model.useGradient {
                    LuminareColorPicker(color: $model.gradientColor, colorNames: (red: "Red", green: "Green", blue: "Blue"))
                }
            }
        }
    }
}
