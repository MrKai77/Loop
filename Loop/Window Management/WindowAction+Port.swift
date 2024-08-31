//
//  WindowAction+Port.swift
//  Loop
//
//  Created by Kai Azim on 2024-03-22.
//

import Defaults
import SwiftUI

/// Extension of WindowAction to add functionality for saving, loading, and managing window actions.
extension WindowAction {
    /// Nested struct to define the format of saved window actions.
    private struct SavedWindowActionFormat: Codable {
        // Properties representing the details of a window action.
        var direction: WindowDirection
        var keybind: Set<CGKeyCode>
        var name: String?
        var unit: CustomWindowActionUnit?
        var anchor: CustomWindowActionAnchor?
        var sizeMode: CustomWindowActionSizeMode?
        var width: Double?
        var height: Double?
        var positionMode: CustomWindowActionPositionMode?
        var xPoint: Double?
        var yPoint: Double?
        var cycle: [SavedWindowActionFormat]?

        /// Converts the saved format back into a usable WindowAction object.
        func convertToWindowAction() -> WindowAction {
            WindowAction(direction, keybind: keybind, name: name, unit: unit, anchor: anchor, width: width, height: height, xPoint: xPoint, yPoint: yPoint, positionMode: positionMode, sizeMode: sizeMode, cycle: cycle?.map { $0.convertToWindowAction() })
        }
    }

    /// Converts a WindowAction object into the saved format.
    private func convertToSavedWindowActionFormat() -> SavedWindowActionFormat {
        SavedWindowActionFormat(direction: direction, keybind: keybind, name: name, unit: unit, anchor: anchor, sizeMode: sizeMode, width: width, height: height, positionMode: positionMode, xPoint: xPoint, yPoint: yPoint, cycle: cycle?.map { $0.convertToSavedWindowActionFormat() })
    }

    /// Presents a prompt to export current keybinds to a JSON file.
    static func exportPrompt() {
        // Check if there are any keybinds to export.
        guard !Defaults[.keybinds].isEmpty else {
            showAlert(
                .init(
                    localized: "Export empty keybinds alert title",
                    defaultValue: "No Keybinds Have Been Set"
                ),
                informativeText: .init(
                    localized: "Export empty keybinds alert description",
                    defaultValue: "You can't export something that doesn't exist!"
                )
            )
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let exportKeybinds = Defaults[.keybinds].map { $0.convertToSavedWindowActionFormat() }
            let keybindsData = try encoder.encode(exportKeybinds)
            if let json = String(data: keybindsData, encoding: .utf8) {
                attemptSave(of: json)
            }
        } catch {
            print("Error encoding keybinds: \(error.localizedDescription)")
        }
    }

    /// Attempts to save the exported JSON string to a file.
    private static func attemptSave(of keybindsData: String) {
        guard let data = keybindsData.data(using: .utf8) else { return }
        let savePanel = NSSavePanel()
        savePanel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        savePanel.title = .init(localized: "Export keybinds")
        savePanel.nameFieldStringValue = "keybinds.json"
        savePanel.allowedContentTypes = [.json]

        savePanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { result in
            guard result == .OK, let destUrl = savePanel.url else { return }
            do {
                try data.write(to: destUrl)
            } catch {
                print("Error writing to file: \(error.localizedDescription)")
            }
        }
    }

    /// Presents a prompt to import keybinds from a JSON file.
    static func importPrompt() {
        let openPanel = NSOpenPanel()
        openPanel.title = .init(localized: "Select Loop keybinds file")
        openPanel.allowedContentTypes = [.json]
        openPanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { result in
            guard result == .OK, let selectedFileURL = openPanel.url else { return }
            do {
                let jsonString = try String(contentsOf: selectedFileURL)
                importKeybinds(from: jsonString)
            } catch {
                print("Error reading file: \(error.localizedDescription)")
            }
        }
    }

    /// Imports keybinds from a JSON string.
    private static func importKeybinds(from jsonString: String) {
        do {
            guard let keybindsData = jsonString.data(using: .utf8) else { return }
            let decoder = JSONDecoder()
            let importedKeybinds = try decoder.decode([SavedWindowActionFormat].self, from: keybindsData)
            updateDefaults(with: importedKeybinds)
        } catch {
            showAlert(
                .init(
                    localized: "Error reading keybinds alert title",
                    defaultValue: "Error Reading Keybinds"
                ),
                informativeText: .init(
                    localized: "Error reading keybinds alert description",
                    defaultValue: "Make sure the file you selected is in the correct format."
                )
            )
        }
    }

    /// Updates the app's defaults with the imported keybinds.
    private static func updateDefaults(with importedKeybinds: [SavedWindowActionFormat]) {
        if Defaults[.keybinds].isEmpty {
            Defaults[.keybinds] = importedKeybinds.map { $0.convertToWindowAction() }
            // Post a notification after updating the keybinds
            NotificationCenter.default.post(name: .keybindsUpdated, object: nil)
        } else {
            showAlertForImportDecision { decision in
                switch decision {
                case .merge:
                    let newKeybinds = importedKeybinds.filter { savedKeybind in
                        !Defaults[.keybinds].contains { $0.keybind == savedKeybind.keybind && $0.name == savedKeybind.name }
                    }
                    Defaults[.keybinds].append(contentsOf: newKeybinds.map { $0.convertToWindowAction() })
                    // Post a notification after updating the keybinds
                    NotificationCenter.default.post(name: .keybindsUpdated, object: nil)
                case .erase:
                    Defaults[.keybinds] = importedKeybinds.map { $0.convertToWindowAction() }
                    // Post a notification after updating the keybinds
                    NotificationCenter.default.post(name: .keybindsUpdated, object: nil)
                case .cancel:
                    // No action needed, no notification should be posted
                    break
                }
            }
        }
    }

    /// Presents a decision alert for how to handle imported keybinds.
    private static func showAlertForImportDecision(completion: @escaping (ImportDecision) -> ()) {
        showAlert(
            .init(localized: "Import Keybinds"),
            informativeText: .init(localized: "Do you want to merge or erase existing keybinds?"),
            buttons: [
                .init(localized: "Import keybinds: merge", defaultValue: "Merge"),
                .init(localized: "Import keybinds: erase", defaultValue: "Erase"),
                .init(localized: "Import keybinds: cancel", defaultValue: "Cancel")
            ]
        ) { response in
            switch response {
            case .alertFirstButtonReturn:
                completion(.merge)
            case .alertSecondButtonReturn:
                completion(.erase)
            default:
                completion(.cancel)
            }
        }
    }

    /// Utility function to show an alert with a completion handler.
    private static func showAlert(
        _ messageText: String,
        informativeText: String,
        buttons: [String] = [],
        completion: ((NSApplication.ModalResponse) -> ())? = nil
    ) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        buttons.forEach { alert.addButton(withTitle: $0) }
        if let completion {
            alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: completion)
        } else {
            alert.runModal()
        }
    }

    /// Enum to represent the decision made in the import decision alert.
    enum ImportDecision {
        case merge, erase, cancel
    }
}
