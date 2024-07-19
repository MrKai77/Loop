//
//  AccentColorConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import Defaults
import Luminare
import SwiftUI

// MARK: - Model

class AccentColorConfigurationModel: ObservableObject {
    // MARK: Defaults

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

    // MARK: Color mode helpers

    var isCustom: Bool {
        useSystemAccentColor ? false : !processWallpaper
    }

    var isWallpaper: Bool {
        processWallpaper && !useSystemAccentColor
    }

    var accentColorOption: AccentColorOption {
        get {
            useSystemAccentColor ? .system : (processWallpaper ? .wallpaper : .custom)
        }
        set {
            useSystemAccentColor = newValue == .system
            processWallpaper = newValue == .wallpaper
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

// MARK: - AccentColorOption

enum AccentColorOption: CaseIterable {
    case system
    case wallpaper
    case custom

    var image: Image {
        switch self {
        case .system: Image(systemName: "apple.logo")
        case .wallpaper: Image(._18PxImageDepth)
        case .custom: Image(._18PxColorPalette)
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
    @StateObject private var model = AccentColorConfigurationModel()

    var body: some View {
        LuminareSection {
            LuminarePicker(
                elements: AccentColorOption.allCases,
                selection: $model.accentColorOption.animation(LuminareSettingsWindow.animation),
                columns: 3,
                roundBottom: model.useSystemAccentColor
            ) { option in
                VStack(spacing: 6) {
                    Spacer()
                    option.image
                    // Notice to disable screen recording, however, keep it in the list.
                    if option == .wallpaper, model.processWallpaper {
                        HStack(spacing: 0) {
                            Text(option.text)
                            LuminareInfoView("Please press deny when Loop \n requests screen recording permissions.", .orange)
                        }
                        .fixedSize()
                    } else {
                        Text(option.text)
                    }
                    Spacer()
                }
                .font(.title3)
                .frame(height: 90)
            }

            if model.isCustom || model.isWallpaper {
                LuminareToggle("Gradient", isOn: $model.useGradient)
                    .animation(LuminareSettingsWindow.animation, value: model.useGradient)
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
