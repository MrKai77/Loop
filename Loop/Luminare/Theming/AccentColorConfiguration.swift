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

    @Published var wallpaperSyncInterval: TimeInterval = Defaults[.wallpaperSyncInterval] {
        didSet {
            Defaults[.wallpaperSyncInterval] = wallpaperSyncInterval
            updateWallpaperSyncTimerInterval()
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
            // NSLog("Wallpaper sync timer is already running.")
            return
        }
        wallpaperSyncTimer = Timer.scheduledTimer(withTimeInterval: wallpaperSyncInterval, repeats: true) { [weak self] _ in
            self?.fetchWallpaperColors()
        }
        // NSLog("Wallpaper sync timer started.")
    }

    private func updateWallpaperSyncTimerInterval() {
        stopWallpaperSyncTimer()
        startWallpaperSyncTimer()
    }

    private func stopWallpaperSyncTimer() {
        if let timer = wallpaperSyncTimer {
            timer.invalidate()
            // NSLog("Wallpaper sync timer stopped.")
        } else {
            // NSLog("No wallpaper sync timer to stop.")
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

    // Change the type of wallpaperSyncIntervalInMinutes to Double
    var wallpaperSyncIntervalInMinutes: Double {
        get {
            Double(wallpaperSyncInterval / 60)
        }
        set {
            wallpaperSyncInterval = newValue >= 1 ? TimeInterval(newValue * 60) : TimeInterval(newValue)
            Defaults[.wallpaperSyncInterval] = wallpaperSyncInterval
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
                roundBottom: true
            ) { option in
                VStack {
                    Spacer()
                    Image(systemName: model.imageName(for: option))
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
                LuminareToggle("Dynamic Sync", isOn: $model.dynamicWallpaperSyncEnabled.animation(LuminareSettingsWindow.animation))

                #warning("Hi, values need to be adjusting to show S, M or H. No idea how to do this :thumbsup:")
                LuminareValueAdjuster(
                    "Sync Interval",
                    value: $model.wallpaperSyncIntervalInMinutes,
                    sliderRange: 0.5...1440, // Range in minutes (30 seconds to 24 hours)
                    suffix: "min",
                    lowerClamp: true,
                    upperClamp: true
                )

                Button("Sync Wallpaper") {
                    model.fetchWallpaperColors()
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

                LuminareColorPicker(color: $model.customAccentColor, colorNames: (red: "Red", green: "Green", blue: "Blue"))

                if model.useGradient {
                    LuminareColorPicker(color: $model.gradientColor, colorNames: (red: "Red", green: "Green", blue: "Blue"))
                }
            }
        }
    }
}

// MARK: - View Extension

extension AccentColorConfigurationModel {
    var isCustom: Bool {
        !useSystemAccentColor && !processWallpaper
    }

    var isWallpaper: Bool {
        processWallpaper && !useSystemAccentColor
    }

    var accentColorOption: String {
        get {
            if useSystemAccentColor {
                "System"
            } else if processWallpaper {
                "Wallpaper"
            } else {
                "Custom"
            }
        }
        set {
            switch newValue {
            case "System":
                useSystemAccentColor = true
                processWallpaper = false
            case "Custom":
                useSystemAccentColor = false
                processWallpaper = false
            case "Wallpaper":
                useSystemAccentColor = false
                processWallpaper = true
            default:
                break
            }
        }
    }

    func imageName(for option: String) -> String {
        switch option {
        case "System":
            "apple.logo"
        case "Wallpaper":
            "photo.on.rectangle.angled"
        case "Custom":
            "paintpalette"
        default:
            ""
        }
    }
}
