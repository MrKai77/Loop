//
//  AccentColorController.swift
//  Loop
//
//  Created by Kai Azim on 2025-09-06.
//

import Defaults
import OSLog
import SwiftUI

/// In charge of processing and storing an up-to-date version of the user's accent color(s), according to their settings.
/// Automatically refreshes when the user updates the following preferences: `accentColorMode`, `customAccentColor`, `useGradient` and `gradientColor`.
@MainActor
final class AccentColorController: ObservableObject {
    static let shared = AccentColorController()

    @Published var color1: Color = Defaults[.lastUsedAccentColor1]
    @Published var color2: Color = Defaults[.lastUsedAccentColor2]

    private let wallpaperProcessor = WallpaperProcessor()
    private var observationTask: Task<(), Never>?
    private let logger = Logger(category: "AccentColorController")

    private init() {
        self.observationTask = Task { [weak self] in
            let updates = Defaults.updates(
                .accentColorMode,
                .customAccentColor,
                .useGradient,
                .gradientColor
            )

            for await _ in updates {
                guard
                    !Task.isCancelled,
                    let self
                else {
                    break
                }
                await refresh()
            }
        }
    }

    deinit {
        observationTask?.cancel()
    }

    func refresh() async {
        switch Defaults[.accentColorMode] {
        case .system:
            logger.log("AccentColorController: Refreshing accent color based on system")
            color1 = Color.accentColor
            color2 = Defaults[.useGradient] ? Color(nsColor: NSColor.controlAccentColor.blended(withFraction: 0.5, of: .black)!) : Color.accentColor
        case .wallpaper:
            logger.log("AccentColorController: Refreshing accent color based on wallpaper")
            let colors = await wallpaperProcessor.fetchLatest()
            color1 = colors.primary
            color2 = Defaults[.useGradient] ? colors.secondary : colors.primary
        case .custom:
            logger.log("AccentColorController: Refreshing accent color based on custom colors")
            color1 = Defaults[.customAccentColor]
            color2 = Defaults[.useGradient] ? Defaults[.gradientColor] : Defaults[.customAccentColor]
        }

        Defaults[.lastUsedAccentColor1] = color1
        Defaults[.lastUsedAccentColor2] = color2
    }
}

extension Color {
    static var systemGray: Color {
        Color(nsColor: NSColor.systemGray.blended(withFraction: 0.2, of: .black)!)
    }
}
