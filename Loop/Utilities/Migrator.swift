//
//  Migrator.swift
//  Loop
//
//  Created by Kai Azim on 2024-03-22.
//

import Defaults
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Migrator

enum MigratorError: Error {
    case settingsEmpty
    case failedToConvertToString
    case mainWindowNotAvailableForPanel
    case fileSelectionCancelled
    case directorySelectionCancelled
    case failedToReadFile
    case invalidPlistFormat
    case importFailed
    case backupFailed

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
        case .invalidPlistFormat:
            "Invalid plist file format."
        case .importFailed:
            "Failed to import settings."
        case .backupFailed:
            "Failed to create backup."
        }
    }
}

// Adds functionality for saving, loading, and managing Loop settings.
enum Migrator {
    private static var documentsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    /// Presents a prompt to export current settings to a plist file.
    static func exportPrompt() async throws {
        let fileURL = try await getSaveDirectoryURL()
        try await saveSettings(to: fileURL)

        Notification.Name.didExportSettingsSuccessfully.post()
    }

    /// Presents a prompt to import settings from a plist file.
    static func importPrompt() async throws {
        let fileURL = try await getSettingsFileURL()

        do {
            try await importSettings(from: fileURL)
        } catch {
            let errorTitle: String
            let errorMessage: String

            switch error {
            case MigratorError.failedToReadFile:
                errorTitle = .init(
                    localized: "Error reading settings alert title",
                    defaultValue: "Error Reading Settings"
                )
                errorMessage = .init(
                    localized: "Error reading settings alert description",
                    defaultValue: "Make sure the file you selected is in the correct format."
                )
            case MigratorError.invalidPlistFormat:
                errorTitle = .init(
                    localized: "Invalid file format alert title",
                    defaultValue: "Invalid File Format"
                )
                errorMessage = .init(
                    localized: "Invalid file format alert description",
                    defaultValue: "The selected file is not a valid Loop settings file."
                )
            case MigratorError.backupFailed:
                errorTitle = .init(
                    localized: "Backup failed alert title",
                    defaultValue: "Backup Failed"
                )
                errorMessage = .init(
                    localized: "Backup failed alert description",
                    defaultValue: "Failed to create backup or copy settings file."
                )
            default:
                throw error
            }

            await showAlert(errorTitle, informativeText: errorMessage)
        }
    }
}

// MARK: Migrator + Export

private extension Migrator {
    /// Presents a save panel to select a location for exporting settings.
    @MainActor
    static func getSaveDirectoryURL() async throws -> URL {
        let savePanel = NSSavePanel()
        savePanel.directoryURL = Defaults[.lastMigratorURL] ?? documentsDirectory
        savePanel.title = .init(localized: "Export settings")
        savePanel.nameFieldStringValue = "Loop Settings.plist"

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

    /// Saves the current settings to the specified file URL.
    static func saveSettings(to fileURL: URL) async throws {
        let fileManager = FileManager.default
        let sourceURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.MrKai77.Loop.plist")

        // Ensure the source file exists
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw MigratorError.failedToReadFile
        }

        // If destination file already exists, remove it first
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                throw MigratorError.backupFailed
            }
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: fileURL)
        } catch {
            throw MigratorError.backupFailed
        }

        await showExportSuccessAlert()
    }

    static func showExportSuccessAlert() async {
        await showAlert(
            .init(localized: "Export Successful"),
            informativeText: .init(localized: "Settings have been exported successfully.")
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
        openPanel.title = .init(localized: "Select a settings file")
        openPanel.allowedContentTypes = [.propertyList]

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

    /// Imports settings from a plist file.
    static func importSettings(from fileURL: URL) async throws {
        guard validatePlistFile(at: fileURL) else {
            throw MigratorError.invalidPlistFormat
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw MigratorError.failedToReadFile
        }

        let plist: Any
        do {
            plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        } catch {
            throw MigratorError.invalidPlistFormat
        }

        let defaults = UserDefaults.standard

        if await showImportConfirmationAlert() {
            // Create backup before importing
            try await createBackupBeforeImport()

            for (key, value) in plist as? [String: Any] ?? [:] {
                defaults.set(value, forKey: key)
            }

            await reloadUserDefaults()
            await showImportSuccessAlert()

            Notification.Name.didImportSettingsSuccessfully.post()
        }
    }

    /// Shows confirmation alert before importing settings.
    static func showImportConfirmationAlert() async -> Bool {
        let response = await showAlert(
            .init(localized: "Import Settings Confirmation"),
            informativeText: .init(localized: "This will replace all current settings. Do you want to continue?"),
            buttons: [
                .init(localized: "Import settings: continue", defaultValue: "Continue"),
                .init(localized: "Import settings: cancel", defaultValue: "Cancel")
            ]
        )

        return response == .alertFirstButtonReturn
    }

    static func showImportSuccessAlert() async {
        await showAlert(
            .init(localized: "Import Successful"),
            informativeText: .init(localized: "Settings have been imported successfully.")
        )
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

    /// Reloads UserDefaults to ensure all changes are applied.
    private static func reloadUserDefaults() async {
        print("Migrator: Forcing UserDefaults reload...")

        CFPreferencesAppSynchronize(Bundle.main.bundleIdentifier! as CFString)
        UserDefaults.standard.synchronize()

        print("Migrator: UserDefaults reload completed")
    }

    /// Validates that the plist file is readable and contains valid preference data
    private static func validatePlistFile(at fileURL: URL) -> Bool {
        do {
            let data = try Data(contentsOf: fileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil)

            // Check if it's a dictionary
            guard let settings = plist as? [String: Any] else {
                print("Migrator: Plist is not a dictionary format")
                return false
            }

            // Check for common macOS preference patterns
            // Accept files that contain preference-like keys or are simply valid dictionaries
            let hasPreferenceKeys = settings.keys.contains { key in
                // Check for common macOS preference patterns
                key.hasPrefix("NS") || // NSUserDefaults keys
                    key.hasPrefix("com.") || // Bundle identifier patterns
                    key.contains("Loop") || // Loop-specific keys
                    key.contains("keybind") || // Keybind-related keys
                    key.contains("setting") || // General setting keys
                    key.contains("config") // Configuration keys
            }

            if !hasPreferenceKeys && !settings.isEmpty {
                print("Migrator: Plist doesn't match expected patterns but contains data - allowing import to proceed")
                return true
            }

            return hasPreferenceKeys || !settings.isEmpty
        } catch {
            print("Migrator: Plist validation failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Creates a backup of current settings before importing
    /// Saves a backup in the Downloads folder
    private static func createBackupBeforeImport() async throws {
        let fileManager = FileManager.default
        let sourceURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.MrKai77.Loop.plist")

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            // No existing settings to backup
            return
        }

        guard let downloadsDirectory = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            throw MigratorError.backupFailed
        }

        let backupURL = downloadsDirectory.appendingPathComponent("Loop Settings Backup.plist")

        // Remove existing backup if it exists
        if fileManager.fileExists(atPath: backupURL.path) {
            do {
                try fileManager.removeItem(at: backupURL)
            } catch {
                print("Migrator: Warning - Could not remove existing backup: \(error)")
            }
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: backupURL)
            print("Migrator: Created backup at \(backupURL.path)")
        } catch {
            print("Migrator: Failed to create backup: \(error)")
            throw MigratorError.backupFailed
        }
    }
}
