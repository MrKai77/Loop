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
    @StateObject private var model = AppDelegate.accentColorConfigurationModel
    private var wallpaperSyncTimer: Timer?

    init() {
        setupWallpaperSync()
    }

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
            if processWallpaper { fetchWallpaperColors() }
        }
    }

    @Published var dynamicWallpaperSyncEnabled = Defaults[.dynamicWallpaperSyncEnabled] {
        didSet {
            Defaults[.dynamicWallpaperSyncEnabled] = dynamicWallpaperSyncEnabled
            handleDynamicWallpaperSyncChange()
        }
    }

    // MARK: - Wallpaper code

    private func handleDynamicWallpaperSyncChange() {
        if dynamicWallpaperSyncEnabled {
            startWallpaperSyncTimer()
        } else {
            stopWallpaperSyncTimer()
        }
    }

    func setupWallpaperSync() {
        if Defaults[.dynamicWallpaperSyncEnabled] {
            startWallpaperSyncTimer()
        }
    }

    private func startWallpaperSyncTimer() {
        guard wallpaperSyncTimer == nil else {
            NSLog("Wallpaper sync timer is already running.")
            return
        }
        wallpaperSyncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.fetchWallpaperColors()
        }
        NSLog("Wallpaper sync timer started.")
    }

    private func stopWallpaperSyncTimer() {
        if let timer = wallpaperSyncTimer {
            timer.invalidate()
            NSLog("Wallpaper sync timer stopped.")
        } else {
            NSLog("No wallpaper sync timer to stop.")
        }
        wallpaperSyncTimer = nil
    }

    private func updateColorsFromWallpaper(with colors: [NSColor]) {
        customAccentColor = Color(colors.first ?? .clear)
        gradientColor = colors.count > 1 ? Color(colors[1]) : gradientColor
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

// MARK: - View

struct AccentColorConfigurationView: View {
    @StateObject private var model = AccentColorConfigurationModel()

    var body: some View {
        LuminareSection {
            LuminarePicker(
                elements: [true, false],
                selection: $model.useSystemAccentColor.animation(LuminareSettingsWindow.animation),
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

            LuminareToggle("Gradient", isOn: $model.useGradient.animation(LuminareSettingsWindow.animation))
            LuminareToggle("Use Wallpaper Colors", isOn: $model.processWallpaper.animation(LuminareSettingsWindow.animation))

            if model.processWallpaper {
                LuminareToggle("Dynamic Wallpaper Sync", isOn: $model.dynamicWallpaperSyncEnabled.animation(LuminareSettingsWindow.animation))

                Button("Sync Wallpaper") {
                    model.fetchWallpaperColors()
                }
            }
        }

        VStack {
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
