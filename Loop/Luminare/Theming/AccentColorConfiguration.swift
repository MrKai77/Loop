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

            #warning("TODO: Return the colors from the wallpaper into the colors section")

            LuminareToggle("Gradient", isOn: $model.useGradient.animation(.smooth(duration: 0.25)))
            LuminareToggle("Use Wallpaper Colors", isOn: $model.processWallpaper.animation(.smooth(duration: 0.25)))

            // Show the auto check toggle only if processWallpaper is true
            if model.processWallpaper {
                LuminareToggle("Dynamic Wallpaper Sync", isOn: $model.autoCheckWallpaper.animation(.smooth(duration: 0.25)))

                // Do we want a force wallpaper button like this in prod? who knows, i don't
                Button("Sync Wallpaper") {
                    WallpaperProcessor.processCurrentWallpaper { result in
                        // Handle the result by printing to console
                        print(result)
                    }
                }
            }
        }

        //  VStack {
        //     if !model.useSystemAccentColor || (model.useGradient && !model.useSystemAccentColor) {
        //         HStack {
        //             Text("Color")
        //             Spacer()
        //         }
        //         .foregroundStyle(.secondary)

        //         LuminareColorPicker(color: $model.customAccentColor, colorNames: (red: "Red", green: "Green", blue: "Blue"))

        //         if model.useGradient {
        //             LuminareColorPicker(color: $model.gradientColor, colorNames: (red: "Red", green: "Green", blue: "Blue"))
        //         }
        //     }
        // }

        VStack {
            // this needs fixing to display in all modal states
            HStack {
                Text("Color")
                Spacer()
            }
            .foregroundStyle(.secondary)

            // Display the color pickers, disabled based on processWallpaper
            LuminareColorPicker(color: $model.customAccentColor, colorNames: (red: "Red", green: "Green", blue: "Blue"))
            // .disabled(model.processWallpaper)

            if model.useGradient {
                LuminareColorPicker(color: $model.gradientColor, colorNames: (red: "Red", green: "Green", blue: "Blue"))
                // .disabled(model.processWallpaper)
            }
        }
    }
}
