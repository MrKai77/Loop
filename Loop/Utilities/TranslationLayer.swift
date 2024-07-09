//
//  TranslationLayer.swift
//  Loop
//
//  Created by Kami on 8/7/2024.
//

import AppKit
import Defaults
import Foundation

/// Represents a keyboard shortcut configuration for a Rectangle action.
struct RectangleShortcut: Codable {
    let keyCode: Int
    let modifierFlags: Int
}

/// Represents the configuration of Rectangle app shortcuts.
struct RectangleConfig: Codable {
    let shortcuts: [String: RectangleShortcut]
}

/// Translates the RectangleConfig to an array of WindowActions for Loop.
/// - Parameter rectangleConfig: The RectangleConfig instance to translate. (this works w/ both normal and pro)
/// - Returns: An array of WindowAction instances corresponding to the RectangleConfig.
func translateRectangleConfigToWindowActions(rectangleConfig: RectangleConfig) -> [WindowAction] {
    // Maps Rectangle direction keys to Loop's WindowDirection enum.
    let directionMapping: [String: WindowDirection] = [
        "bottomHalf": .bottomHalf,
        "bottomRight": .bottomRightQuarter,
        "center": .center,
        "larger": .larger,
        "leftHalf": .leftHalf,
        "maximize": .maximize,
        "nextDisplay": .nextScreen,
        "previousDisplay": .previousScreen,
        "restore": .undo,
        "rightHalf": .rightHalf,
        "smaller": .smaller,
        "topHalf": .topHalf,
        "topLeft": .topLeftQuarter,
        "topRight": .topRightQuarter
    ]

    // Converts the Rectangle shortcuts into Loop's WindowActions.
    return rectangleConfig.shortcuts.compactMap { direction, shortcut in
        guard let loopDirection = directionMapping[direction], !direction.contains("Todo") else { return nil }
        return WindowAction(
            loopDirection,
            keybind: Set([CGKeyCode(shortcut.keyCode)]), // Converts the integer keyCode to CGKeyCode.
            name: direction.capitalized.replacingOccurrences(of: " ", with: "") + "Cycle"
        )
    }
}

/// Initiates the import process for the RectangleConfig.json file.
func importRectangleConfig() {
    let openPanel = NSOpenPanel()
    openPanel.prompt = "Select Rectangle Config File"
    openPanel.allowedContentTypes = [.json]

    // Presents a file open panel to the user.
    openPanel.begin { response in
        guard response == .OK, let selectedFile = openPanel.url else { return }

        // Attempts to decode the selected file into a RectangleConfig object.
        if let rectangleConfig = try? JSONDecoder().decode(RectangleConfig.self, from: Data(contentsOf: selectedFile)) {
            let windowActions = translateRectangleConfigToWindowActions(rectangleConfig: rectangleConfig)
            saveWindowActions(windowActions)
        } else {
            print("Error reading or translating RectangleConfig.json")
        }
    }
}

/// Saves the translated WindowActions into Loop's configuration and posts a notification.
/// - Parameter windowActions: The array of WindowActions to save.
func saveWindowActions(_ windowActions: [WindowAction]) {
    for action in windowActions {
        print("Direction: \(action.direction), Keybind: \(action.keybind), Name: \(action.name ?? "")")
    }

    // Stores the WindowActions into Loop's configuration.
    Defaults[.keybinds] = windowActions

    // Post a notification after saving the new keybinds
    NotificationCenter.default.post(name: .keybindsUpdated, object: nil)
}

/// Starts the import process for Rectangle configuration.
func initiateImportProcess() {
    importRectangleConfig()
}
