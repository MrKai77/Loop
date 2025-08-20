//
//  Migrator.swift
//  Loop
//
//  Created by Kai Azim on 2024-03-22.
//

import Defaults
import SwiftUI

// MARK: - Saved Settings Format

/// Struct to represent the JSON contents of a Loop settings file.
struct SavedSettingsFormat: Codable {
    let version: String?
    let actions: [SavedWindowActionFormat]

    // Icon
    let currentIcon: String?
    let timesLooped: Int?
    let showDockIcon: Bool?
    let notificationWhenIconUnlocked: Bool?

    // Accent Color
    let useSystemAccentColor: Bool?
    let customAccentColor: Color?
    let useGradient: Bool?
    let gradientColor: Color?
    let processWallpaper: Bool?

    // Radial Menu
    let radialMenuVisibility: Bool?
    let radialMenuCornerRadius: CGFloat?
    let radialMenuThickness: CGFloat?
    let lockRadialMenuToCenter: Bool?

    // Preview
    let previewVisibility: Bool?
    let previewPadding: CGFloat?
    let previewCornerRadius: CGFloat?
    let previewBorderThickness: CGFloat?

    // Behavior
    let launchAtLogin: Bool?
    let hideMenuBarIcon: Bool?
    let animationConfiguration: AnimationConfiguration?
    let windowSnapping: Bool?
    let restoreWindowFrameOnDrag: Bool?
    let enablePadding: Bool?
    let padding: PaddingModel?
    let useScreenWithCursor: Bool?
    let moveCursorWithWindow: Bool?
    let resizeWindowUnderCursor: Bool?
    let focusWindowOnResize: Bool?
    let respectStageManager: Bool?
    let stageStripSize: CGFloat?
    let animateStashedWindows: Bool?
    let stashedWindowVisiblePadding: CGFloat?
    let shiftFocusWhenStashed: Bool?
    let cycleModeRestartEnabled: Bool?

    // Keybinds
    let triggerKey: Set<CGKeyCode>?
    let triggerDelay: Double?
    let doubleClickToTrigger: Bool?
    let middleClickTriggersLoop: Bool?
    let cycleBackwardsOnShiftPressed: Bool?
    let keybinds: [WindowAction]?

    // Advanced
    let useSystemWindowManagerWhenAvailable: Bool?
    let animateWindowResizes: Bool?
    let disableCursorInteraction: Bool?
    let ignoreFullscreen: Bool?
    let hideUntilDirectionIsChosen: Bool?
    let hapticFeedback: Bool?

    // About
    let includeDevelopmentVersions: Bool?
    let updatesEnabled: Bool?

    let excludedApps: [URL]?
    let sizeIncrement: CGFloat?

    static func generateFromDefaults() -> SavedSettingsFormat {
        SavedSettingsFormat(
            version: Bundle.main.appVersion,
            actions: Defaults[.keybinds].map { SavedWindowActionFormat($0) },

            // Icon
            currentIcon: Defaults[.currentIcon],
            timesLooped: Defaults[.timesLooped],
            showDockIcon: Defaults[.showDockIcon],
            notificationWhenIconUnlocked: Defaults[.notificationWhenIconUnlocked],

            // Accent Color
            useSystemAccentColor: Defaults[.useSystemAccentColor],
            customAccentColor: Defaults[.customAccentColor],
            useGradient: Defaults[.useGradient],
            gradientColor: Defaults[.gradientColor],
            processWallpaper: Defaults[.processWallpaper],

            // Radial Menu
            radialMenuVisibility: Defaults[.radialMenuVisibility],
            radialMenuCornerRadius: Defaults[.radialMenuCornerRadius],
            radialMenuThickness: Defaults[.radialMenuThickness],
            lockRadialMenuToCenter: Defaults[.lockRadialMenuToCenter],

            // Preview
            previewVisibility: Defaults[.previewVisibility],
            previewPadding: Defaults[.previewPadding],
            previewCornerRadius: Defaults[.previewCornerRadius],
            previewBorderThickness: Defaults[.previewBorderThickness],

            // Behavior
            launchAtLogin: Defaults[.launchAtLogin],
            hideMenuBarIcon: Defaults[.hideMenuBarIcon],
            animationConfiguration: Defaults[.animationConfiguration],
            windowSnapping: Defaults[.windowSnapping],
            restoreWindowFrameOnDrag: Defaults[.restoreWindowFrameOnDrag],
            enablePadding: Defaults[.enablePadding],
            padding: Defaults[.padding],
            useScreenWithCursor: Defaults[.useScreenWithCursor],
            moveCursorWithWindow: Defaults[.moveCursorWithWindow],
            resizeWindowUnderCursor: Defaults[.resizeWindowUnderCursor],
            focusWindowOnResize: Defaults[.focusWindowOnResize],
            respectStageManager: Defaults[.respectStageManager],
            stageStripSize: Defaults[.stageStripSize],
            animateStashedWindows: Defaults[.animateStashedWindows],
            stashedWindowVisiblePadding: Defaults[.stashedWindowVisiblePadding],
            shiftFocusWhenStashed: Defaults[.shiftFocusWhenStashed],
            cycleModeRestartEnabled: Defaults[.cycleModeRestartEnabled],

            // Keybinds
            triggerKey: Defaults[.triggerKey],
            triggerDelay: Defaults[.triggerDelay],
            doubleClickToTrigger: Defaults[.doubleClickToTrigger],
            middleClickTriggersLoop: Defaults[.middleClickTriggersLoop],
            cycleBackwardsOnShiftPressed: Defaults[.cycleBackwardsOnShiftPressed],
            keybinds: Defaults[.keybinds],

            // Advanced
            useSystemWindowManagerWhenAvailable: Defaults[.useSystemWindowManagerWhenAvailable],
            animateWindowResizes: Defaults[.animateWindowResizes],
            disableCursorInteraction: Defaults[.disableCursorInteraction],
            ignoreFullscreen: Defaults[.ignoreFullscreen],
            hideUntilDirectionIsChosen: Defaults[.hideUntilDirectionIsChosen],
            hapticFeedback: Defaults[.hapticFeedback],

            // About
            includeDevelopmentVersions: Defaults[.includeDevelopmentVersions],
            updatesEnabled: Defaults[.updatesEnabled],

            excludedApps: Defaults[.excludedApps],
            sizeIncrement: Defaults[.sizeIncrement]
        )
    }
}

// MARK: - SavedWindowActionFormat

/// Struct to define the format of saved window actions.
struct SavedWindowActionFormat: Codable {
    let direction: WindowDirection
    let keybind: Set<CGKeyCode>
    let name: String?
    let unit: CustomWindowActionUnit?
    let anchor: CustomWindowActionAnchor?
    let sizeMode: CustomWindowActionSizeMode?
    let width: Double?
    let height: Double?
    let positionMode: CustomWindowActionPositionMode?
    let xPoint: Double?
    let yPoint: Double?
    let cycle: [SavedWindowActionFormat]?

    /// Initialize from a WindowAction.
    init(_ action: WindowAction) {
        self.direction = action.direction
        self.keybind = action.keybind
        self.name = action.name
        self.unit = action.unit
        self.anchor = action.anchor
        self.sizeMode = action.sizeMode
        self.width = action.width
        self.height = action.height
        self.positionMode = action.positionMode
        self.xPoint = action.xPoint
        self.yPoint = action.yPoint
        self.cycle = action.cycle?.map { SavedWindowActionFormat($0) }
    }

    /// Converts the saved format back into a usable WindowAction object.
    func convertToWindowAction() -> WindowAction {
        WindowAction(
            direction,
            keybind: keybind,
            name: name,
            unit: unit,
            anchor: anchor,
            width: width,
            height: height,
            xPoint: xPoint,
            yPoint: yPoint,
            positionMode: positionMode,
            sizeMode: sizeMode,
            cycle: cycle?.map { $0.convertToWindowAction()
            }
        )
    }
}

// MARK: - Migrator

enum MigratorError: Error {
    case settingsEmpty
    case failedToConvertToString
    case mainWindowNotAvailableForPanel
    case fileSelectionCancelled
    case directorySelectionCancelled
    case failedToReadFile

    var localizedDescription: String {
        switch self {
        case .settingsEmpty:
            "Settings are empty."
        case .failedToConvertToString:
            "Failed to convert settings to string."
        case .mainWindowNotAvailableForPanel:
            "Main window not available for panel."
        case .fileSelectionCancelled:
            "File selection was cancelled."
        case .directorySelectionCancelled:
            "Directory selection was cancelled."
        case .failedToReadFile:
            "Failed to read file."
        }
    }
}

// Adds functionality for saving, loading, and managing settings.
enum Migrator {
    private static var documentsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    /// Presents a prompt to export current settings to a JSON file.
    static func exportPrompt() async throws {
        // Check if there are any keybinds to export.
        guard !Defaults[.keybinds].isEmpty else {
            await showAlert(
                .init(
                    localized: "Export empty keybinds alert title",
                    defaultValue: "No Keybinds Have Been Set"
                ),
                informativeText: .init(
                    localized: "Export empty keybinds alert description",
                    defaultValue: "You can't export something that doesn't exist!"
                )
            )

            throw MigratorError.settingsEmpty
        }

        let directoryURL = try await getSaveDirectoryURL()
        let settings = SavedSettingsFormat.generateFromDefaults()
        try await saveSettings(settings, in: directoryURL)

        Notification.Name.didExportSettingsSuccessfully.post()
    }

    /// Presents a prompt to import settings from a JSON file.
    static func importPrompt() async throws {
        let fileURL = try await getSettingsFileURL()
        let jsonString = try String(contentsOf: fileURL)

        do {
            try await importSettings(from: jsonString)
        } catch {
            if case MigratorError.failedToReadFile = error {
                await showAlert(
                    .init(
                        localized: "Error reading keybinds alert title",
                        defaultValue: "Error Reading Keybinds"
                    ),
                    informativeText: .init(
                        localized: "Error reading keybinds alert description",
                        defaultValue: "Make sure the file you selected is in the correct format."
                    )
                )
            } else {
                throw error
            }
        }
    }
}

// MARK: Migrator + Export

private extension Migrator {
    /// Presents a save panel to select a directory for exporting settings.
    @MainActor
    static func getSaveDirectoryURL() async throws -> URL {
        let savePanel = NSSavePanel()
        savePanel.directoryURL = Defaults[.lastMigratorURL] ?? documentsDirectory
        savePanel.title = .init(localized: "Export keybinds")
        savePanel.nameFieldStringValue = "Loop Settings.json"

        guard let window = NSApplication.shared.mainWindow else {
            throw MigratorError.mainWindowNotAvailableForPanel
        }

        let result = await savePanel.beginSheetModal(for: window)

        guard result == .OK, let selectedFileURL = savePanel.url else {
            throw MigratorError.directorySelectionCancelled
        }

        // Save the last used directory for future exports
        Defaults[.lastMigratorURL] = selectedFileURL.deletingLastPathComponent()

        return selectedFileURL
    }

    /// Saves the settings in the specified directory URL.
    static func saveSettings(_: SavedSettingsFormat, in directoryURL: URL) async throws {
        let settings = SavedSettingsFormat.generateFromDefaults()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Convert to a dictionary we can manipulate before final encoding
        var rootDict = try JSONSerialization.jsonObject(
            with: encoder.encode(settings),
            options: [.mutableContainers]
        ) as! [String: Any]

        // Process trigger key if present
        if var triggerKey = rootDict["triggerKey"] as? [CGKeyCode] {
            triggerKey.sort()
            rootDict["triggerKey"] = triggerKey
        }

        // Process actions array
        if var actions = rootDict["actions"] as? [[String: Any]] {
            // First ensure all keybind arrays are sorted
            for i in 0 ..< actions.count {
                // Sort the keybind array in each action
                if var keybind = actions[i]["keybind"] as? [CGKeyCode] {
                    keybind.sort()
                    actions[i]["keybind"] = keybind
                }

                // Handle nested cycle actions if present
                if var cycle = actions[i]["cycle"] as? [[String: Any]] {
                    // Sort the cycle actions by direction
                    cycle.sort { first, second -> Bool in
                        let firstDir = first["direction"] as? String ?? ""
                        let secondDir = second["direction"] as? String ?? ""
                        return firstDir < secondDir
                    }

                    // For each action in the cycle
                    for j in 0 ..< cycle.count {
                        // Sort the keybind array in each cycle action
                        if var cycleKeybind = cycle[j]["keybind"] as? [CGKeyCode] {
                            cycleKeybind.sort()
                            cycle[j]["keybind"] = cycleKeybind
                        }
                    }
                    actions[i]["cycle"] = cycle
                }
            }

            // Sort the actions array by direction and keybind for a consistent ordering
            actions.sort { first, second -> Bool in
                // First compare by direction
                let firstDir = first["direction"] as? String ?? ""
                let secondDir = second["direction"] as? String ?? ""

                if firstDir != secondDir {
                    return firstDir < secondDir
                }

                // If directions are equal, compare by name (if present)
                let firstName = first["name"] as? String ?? ""
                let secondName = second["name"] as? String ?? ""

                if firstName != secondName {
                    return firstName < secondName
                }

                // If names are equal or empty, compare by keybind
                let firstKeybind = first["keybind"] as? [CGKeyCode] ?? []
                let secondKeybind = second["keybind"] as? [CGKeyCode] ?? []

                // Convert keybinds to strings for comparison
                let firstKeyStr = firstKeybind.map { String($0) }.joined(separator: "-")
                let secondKeyStr = secondKeybind.map { String($0) }.joined(separator: "-")

                return firstKeyStr < secondKeyStr
            }

            rootDict["actions"] = actions
        }

        // Convert back to JSON data with our sorted arrays
        let sortedData = try JSONSerialization.data(
            withJSONObject: rootDict,
            options: [.prettyPrinted, .sortedKeys]
        )

        guard let json = String(data: sortedData, encoding: .utf8) else {
            throw MigratorError.failedToConvertToString
        }

        try json.write(
            to: directoryURL,
            atomically: true,
            encoding: .utf8
        )
    }
}

// MARK: Migrator + Import

private extension Migrator {
    /// Presents a file picker to select a settings file.
    @MainActor
    static func getSettingsFileURL() async throws -> URL {
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = Defaults[.lastMigratorURL] ?? documentsDirectory
        openPanel.title = .init(localized: "Select a keybinds file")
        openPanel.allowedContentTypes = [.json]

        guard let window = NSApplication.shared.mainWindow else {
            throw MigratorError.mainWindowNotAvailableForPanel
        }

        let result = await openPanel.beginSheetModal(for: window)

        guard result == .OK, let selectedFileURL = openPanel.url else {
            throw MigratorError.fileSelectionCancelled
        }

        // Save the last used directory for future imports
        Defaults[.lastMigratorURL] = selectedFileURL.deletingLastPathComponent()

        return selectedFileURL
    }

    /// Imports settings from a JSON string.
    static func importSettings(from jsonString: String) async throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw MigratorError.failedToReadFile
        }

        /// First, try to import the general Loop settings format.
        do {
            let savedData = try await importLoopSettings(from: data)
            await updateDefaults(with: savedData)
            return
        } catch {
            print("Error importing Loop settings: \(error)")
        }

        /// If that fails, try to import the old Loop (pre 1.2.0) keybinds format.
        do {
            let savedData = try await importLoopLegacySettings(from: data)
            await updateDefaults(with: savedData)
            return
        } catch {
            print("Error importing Loop (pre 1.2.0) keybinds: \(error)")
        }

        /// If that fails, try to import the Rectangle keybinds format.
        do {
            let savedData = try await importRectangleSettings(from: data)
            await updateDefaults(with: savedData)
            return
        } catch {
            print("Error importing Rectangle keybinds: \(error)")
        }

        // If all attempts fail, show an error alert.
        throw MigratorError.failedToReadFile
    }

    /// Tries to import Loop's settings format.
    static func importLoopSettings(from data: Data) async throws -> SavedSettingsFormat {
        let decoder = JSONDecoder()
        let settings = try decoder.decode(SavedSettingsFormat.self, from: data)
        return settings
    }

    /// Tries to import Loop's old (pre 1.2.0) keybinds format.
    static func importLoopLegacySettings(from data: Data) async throws -> SavedSettingsFormat {
        let decoder = JSONDecoder()
        let keybinds = try decoder.decode([SavedWindowActionFormat].self, from: data)

        // Create a SavedSettingsFormat with only version and actions, all other fields will be nil
        return SavedSettingsFormat(
            version: nil,
            actions: keybinds,
            currentIcon: nil, timesLooped: nil, showDockIcon: nil, notificationWhenIconUnlocked: nil,
            useSystemAccentColor: nil, customAccentColor: nil, useGradient: nil, gradientColor: nil, processWallpaper: nil,
            radialMenuVisibility: nil, radialMenuCornerRadius: nil, radialMenuThickness: nil, lockRadialMenuToCenter: nil,
            previewVisibility: nil, previewPadding: nil, previewCornerRadius: nil, previewBorderThickness: nil,
            launchAtLogin: nil, hideMenuBarIcon: nil, animationConfiguration: nil, windowSnapping: nil, restoreWindowFrameOnDrag: nil,
            enablePadding: nil, padding: nil, useScreenWithCursor: nil, moveCursorWithWindow: nil, resizeWindowUnderCursor: nil,
            focusWindowOnResize: nil, respectStageManager: nil, stageStripSize: nil, animateStashedWindows: nil,
            stashedWindowVisiblePadding: nil, shiftFocusWhenStashed: nil, cycleModeRestartEnabled: nil,
            triggerKey: nil, triggerDelay: nil, doubleClickToTrigger: nil, middleClickTriggersLoop: nil,
            cycleBackwardsOnShiftPressed: nil, keybinds: nil,
            useSystemWindowManagerWhenAvailable: nil, animateWindowResizes: nil, disableCursorInteraction: nil,
            ignoreFullscreen: nil, hideUntilDirectionIsChosen: nil, hapticFeedback: nil,
            includeDevelopmentVersions: nil, updatesEnabled: nil, excludedApps: nil, sizeIncrement: nil
        )
    }

    /// Tries to import Rectangle's keybinds format.
    static func importRectangleSettings(from data: Data) async throws -> SavedSettingsFormat {
        let keybinds = try RectangleTranslationLayer.importKeybinds(from: data)

        // Create a SavedSettingsFormat with only version and actions, all other fields will be nil
        return SavedSettingsFormat(
            version: nil,
            actions: keybinds,
            currentIcon: nil, timesLooped: nil, showDockIcon: nil, notificationWhenIconUnlocked: nil,
            useSystemAccentColor: nil, customAccentColor: nil, useGradient: nil, gradientColor: nil, processWallpaper: nil,
            radialMenuVisibility: nil, radialMenuCornerRadius: nil, radialMenuThickness: nil, lockRadialMenuToCenter: nil,
            previewVisibility: nil, previewPadding: nil, previewCornerRadius: nil, previewBorderThickness: nil,
            launchAtLogin: nil, hideMenuBarIcon: nil, animationConfiguration: nil, windowSnapping: nil, restoreWindowFrameOnDrag: nil,
            enablePadding: nil, padding: nil, useScreenWithCursor: nil, moveCursorWithWindow: nil, resizeWindowUnderCursor: nil,
            focusWindowOnResize: nil, respectStageManager: nil, stageStripSize: nil, animateStashedWindows: nil,
            stashedWindowVisiblePadding: nil, shiftFocusWhenStashed: nil, cycleModeRestartEnabled: nil,
            triggerKey: nil, triggerDelay: nil, doubleClickToTrigger: nil, middleClickTriggersLoop: nil,
            cycleBackwardsOnShiftPressed: nil, keybinds: nil,
            useSystemWindowManagerWhenAvailable: nil, animateWindowResizes: nil, disableCursorInteraction: nil,
            ignoreFullscreen: nil, hideUntilDirectionIsChosen: nil, hapticFeedback: nil,
            includeDevelopmentVersions: nil, updatesEnabled: nil, excludedApps: nil, sizeIncrement: nil
        )
    }

    // MARK: Saving Imports

    /// Updates the app's defaults with the imported keybinds.
    static func updateDefaults(with savedData: SavedSettingsFormat) async {
        // Import all available settings from SavedSettingsFormat

        // Icon settings
        if let currentIcon = savedData.currentIcon {
            Defaults[.currentIcon] = currentIcon
        }
        if let timesLooped = savedData.timesLooped {
            Defaults[.timesLooped] = timesLooped
        }
        if let showDockIcon = savedData.showDockIcon {
            Defaults[.showDockIcon] = showDockIcon
        }
        if let notificationWhenIconUnlocked = savedData.notificationWhenIconUnlocked {
            Defaults[.notificationWhenIconUnlocked] = notificationWhenIconUnlocked
        }

        // Accent Color settings
        if let useSystemAccentColor = savedData.useSystemAccentColor {
            Defaults[.useSystemAccentColor] = useSystemAccentColor
        }
        if let customAccentColor = savedData.customAccentColor {
            Defaults[.customAccentColor] = customAccentColor
        }
        if let useGradient = savedData.useGradient {
            Defaults[.useGradient] = useGradient
        }
        if let gradientColor = savedData.gradientColor {
            Defaults[.gradientColor] = gradientColor
        }
        if let processWallpaper = savedData.processWallpaper {
            Defaults[.processWallpaper] = processWallpaper
        }

        // Radial Menu settings
        if let radialMenuVisibility = savedData.radialMenuVisibility {
            Defaults[.radialMenuVisibility] = radialMenuVisibility
        }
        if let radialMenuCornerRadius = savedData.radialMenuCornerRadius {
            Defaults[.radialMenuCornerRadius] = radialMenuCornerRadius
        }
        if let radialMenuThickness = savedData.radialMenuThickness {
            Defaults[.radialMenuThickness] = radialMenuThickness
        }
        if let lockRadialMenuToCenter = savedData.lockRadialMenuToCenter {
            Defaults[.lockRadialMenuToCenter] = lockRadialMenuToCenter
        }

        // Preview settings
        if let previewVisibility = savedData.previewVisibility {
            Defaults[.previewVisibility] = previewVisibility
        }
        if let previewPadding = savedData.previewPadding {
            Defaults[.previewPadding] = previewPadding
        }
        if let previewCornerRadius = savedData.previewCornerRadius {
            Defaults[.previewCornerRadius] = previewCornerRadius
        }
        if let previewBorderThickness = savedData.previewBorderThickness {
            Defaults[.previewBorderThickness] = previewBorderThickness
        }

        // Behavior settings
        if let launchAtLogin = savedData.launchAtLogin {
            Defaults[.launchAtLogin] = launchAtLogin
        }
        if let hideMenuBarIcon = savedData.hideMenuBarIcon {
            Defaults[.hideMenuBarIcon] = hideMenuBarIcon
        }
        if let animationConfiguration = savedData.animationConfiguration {
            Defaults[.animationConfiguration] = animationConfiguration
        }
        if let windowSnapping = savedData.windowSnapping {
            Defaults[.windowSnapping] = windowSnapping
        }
        if let restoreWindowFrameOnDrag = savedData.restoreWindowFrameOnDrag {
            Defaults[.restoreWindowFrameOnDrag] = restoreWindowFrameOnDrag
        }
        if let enablePadding = savedData.enablePadding {
            Defaults[.enablePadding] = enablePadding
        }
        if let padding = savedData.padding {
            Defaults[.padding] = padding
        }
        if let useScreenWithCursor = savedData.useScreenWithCursor {
            Defaults[.useScreenWithCursor] = useScreenWithCursor
        }
        if let moveCursorWithWindow = savedData.moveCursorWithWindow {
            Defaults[.moveCursorWithWindow] = moveCursorWithWindow
        }
        if let resizeWindowUnderCursor = savedData.resizeWindowUnderCursor {
            Defaults[.resizeWindowUnderCursor] = resizeWindowUnderCursor
        }
        if let focusWindowOnResize = savedData.focusWindowOnResize {
            Defaults[.focusWindowOnResize] = focusWindowOnResize
        }
        if let respectStageManager = savedData.respectStageManager {
            Defaults[.respectStageManager] = respectStageManager
        }
        if let stageStripSize = savedData.stageStripSize {
            Defaults[.stageStripSize] = stageStripSize
        }
        if let animateStashedWindows = savedData.animateStashedWindows {
            Defaults[.animateStashedWindows] = animateStashedWindows
        }
        if let stashedWindowVisiblePadding = savedData.stashedWindowVisiblePadding {
            Defaults[.stashedWindowVisiblePadding] = stashedWindowVisiblePadding
        }
        if let shiftFocusWhenStashed = savedData.shiftFocusWhenStashed {
            Defaults[.shiftFocusWhenStashed] = shiftFocusWhenStashed
        }
        if let cycleModeRestartEnabled = savedData.cycleModeRestartEnabled {
            Defaults[.cycleModeRestartEnabled] = cycleModeRestartEnabled
        }

        // Keybinds settings
        if let triggerKey = savedData.triggerKey {
            Defaults[.triggerKey] = triggerKey
        }
        if let triggerDelay = savedData.triggerDelay {
            Defaults[.triggerDelay] = triggerDelay
        }
        if let doubleClickToTrigger = savedData.doubleClickToTrigger {
            Defaults[.doubleClickToTrigger] = doubleClickToTrigger
        }
        if let middleClickTriggersLoop = savedData.middleClickTriggersLoop {
            Defaults[.middleClickTriggersLoop] = middleClickTriggersLoop
        }
        if let cycleBackwardsOnShiftPressed = savedData.cycleBackwardsOnShiftPressed {
            Defaults[.cycleBackwardsOnShiftPressed] = cycleBackwardsOnShiftPressed
        }

        // Advanced settings
        if let useSystemWindowManagerWhenAvailable = savedData.useSystemWindowManagerWhenAvailable {
            Defaults[.useSystemWindowManagerWhenAvailable] = useSystemWindowManagerWhenAvailable
        }
        if let animateWindowResizes = savedData.animateWindowResizes {
            Defaults[.animateWindowResizes] = animateWindowResizes
        }
        if let disableCursorInteraction = savedData.disableCursorInteraction {
            Defaults[.disableCursorInteraction] = disableCursorInteraction
        }
        if let ignoreFullscreen = savedData.ignoreFullscreen {
            Defaults[.ignoreFullscreen] = ignoreFullscreen
        }
        if let hideUntilDirectionIsChosen = savedData.hideUntilDirectionIsChosen {
            Defaults[.hideUntilDirectionIsChosen] = hideUntilDirectionIsChosen
        }
        if let hapticFeedback = savedData.hapticFeedback {
            Defaults[.hapticFeedback] = hapticFeedback
        }

        // About settings
        if let includeDevelopmentVersions = savedData.includeDevelopmentVersions {
            Defaults[.includeDevelopmentVersions] = includeDevelopmentVersions
        }
        if let updatesEnabled = savedData.updatesEnabled {
            Defaults[.updatesEnabled] = updatesEnabled
        }

        // Other settings
        if let excludedApps = savedData.excludedApps {
            Defaults[.excludedApps] = excludedApps
        }
        if let sizeIncrement = savedData.sizeIncrement {
            Defaults[.sizeIncrement] = sizeIncrement
        }

        // Handle keybinds import logic
        let importedKeybinds = savedData.keybinds?.map(\.self) ?? savedData.actions.map { $0.convertToWindowAction() }

        if Defaults[.keybinds].isEmpty {
            Defaults[.keybinds] = savedData.actions.map { $0.convertToWindowAction() }

            // Post a notification after updating the keybinds
            Notification.Name.didImportSettingsSuccessfully.post()
        } else {
            let result = await showAlertForImportDecision()

            switch result {
            case .merge:
                let newKeybinds = savedData.actions
                    .map { $0.convertToWindowAction() }
                    .filter { newKeybind in
                        !Defaults[.keybinds].contains { $0.keybind == newKeybind.keybind && $0.name == newKeybind.name }
                    }

                Defaults[.keybinds].append(contentsOf: newKeybinds)

                // Post a notification after updating the keybinds
                Notification.Name.didImportSettingsSuccessfully.post()
            case .erase:
                Defaults[.keybinds] = savedData.actions.map { $0.convertToWindowAction() }

                // Post a notification after updating the keybinds
                Notification.Name.didImportSettingsSuccessfully.post()
            case .cancel:
                // No action needed, no notification should be posted
                break
            }
        }
    }

    /// Presents a decision alert for how to handle imported keybinds.
    static func showAlertForImportDecision() async -> ImportDecision {
        let response = await showAlert(
            .init(localized: "Import Settings"),
            informativeText: .init(localized: "Do you want to merge or erase existing settings?"),
            buttons: [
                .init(localized: "Import settings: merge", defaultValue: "Merge"),
                .init(localized: "Import settings: erase", defaultValue: "Erase"),
                .init(localized: "Import settings: cancel", defaultValue: "Cancel")
            ]
        )

        switch response {
        case .alertFirstButtonReturn:
            return .merge
        case .alertSecondButtonReturn:
            return .erase
        default:
            return .cancel
        }
    }

    /// Utility function to show an alert with a completion handler.
    @MainActor
    @discardableResult
    static func showAlert(
        _ messageText: String,
        informativeText: String,
        buttons: [String] = []
    ) async -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        buttons.forEach { alert.addButton(withTitle: $0) }

        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            return await alert.beginSheetModal(for: window)
        } else {
            return alert.runModal()
        }
    }

    /// Enum to represent the decision made in the import decision alert.
    enum ImportDecision {
        case merge, erase, cancel
    }
}
