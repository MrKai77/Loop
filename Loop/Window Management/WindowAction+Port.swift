//
//  WindowAction+Port.swift
//  Loop
//
//  Created by Kai Azim on 2024-03-22.
//

import Defaults
import SwiftUI

extension WindowAction {
    private struct SavedWindowActionFormat: Codable {
        var direction: WindowDirection
        var keybind: Set<CGKeyCode>

        // MARK: CUSTOM KEYBINDS

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
                cycle: cycle?.map { $0.convertToWindowAction() }
            )
        }
    }

    private func convertToSavedWindowActionFormat() -> SavedWindowActionFormat {
        SavedWindowActionFormat(
            direction: direction,
            keybind: keybind,
            name: name,
            unit: unit,
            anchor: anchor,
            sizeMode: sizeMode,
            width: width,
            height: height,
            positionMode: positionMode,
            xPoint: xPoint,
            yPoint: yPoint,
            cycle: cycle?.map { $0.convertToSavedWindowActionFormat() }
        )
    }

    static func exportPrompt() {
        let keybinds = Defaults[.keybinds]

        if keybinds.isEmpty {
            let alert = NSAlert()
            alert.messageText = "No Keybinds Have Been Set"
            alert.informativeText = "You can't export something that doesn't exist!"
            alert.beginSheetModal(for: NSApplication.shared.mainWindow!)
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let exportKeybinds = keybinds.map {
                $0.convertToSavedWindowActionFormat()
            }

            let keybindsData = try encoder.encode(exportKeybinds)

            if let json = String(data: keybindsData, encoding: .utf8) {
                attemptSave(of: json)
            }
        } catch {
            print("Error encoding keybinds: \(error.localizedDescription)")
        }
    }

    private static func attemptSave(of keybindsData: String) {
        let data = keybindsData.data(using: .utf8)

        let savePanel = NSSavePanel()
        if let downloadsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            savePanel.directoryURL = downloadsUrl
        }

        savePanel.title = "Export Keybinds"
        savePanel.nameFieldStringValue = "keybinds"
        savePanel.allowedContentTypes = [.json]

        savePanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { result in
            if result == .OK, let destUrl = savePanel.url {
                DispatchQueue.main.async {
                    do {
                        try data?.write(to: destUrl)
                    } catch {
                        print("Error writing to file: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    static func importPrompt() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Keybinds"
        openPanel.allowedContentTypes = [.json]

        openPanel.beginSheetModal(for: NSApplication.shared.mainWindow!) { result in
            if result == .OK, let selectedFileURL = openPanel.url {
                DispatchQueue.main.async {
                    do {
                        let jsonString = try String(contentsOf: selectedFileURL)
                        importKeybinds(from: jsonString)
                    } catch {
                        print("Error reading file: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private static func importKeybinds(from jsonString: String) {
        let decoder = JSONDecoder()

        do {
            let keybindsData = jsonString.data(using: .utf8)!
            let importedKeybinds = try decoder.decode([SavedWindowActionFormat].self, from: keybindsData)

            if Defaults[.keybinds].isEmpty {
                for savedKeybind in importedKeybinds {
                    Defaults[.keybinds].append(savedKeybind.convertToWindowAction())
                }
            } else {
                showAlertForImportDecision { decision in
                    switch decision {
                    case .merge:
                        for savedKeybind in importedKeybinds where !Defaults[.keybinds].contains(where: {
                            $0.keybind == savedKeybind.keybind && $0.name == savedKeybind.name
                        }) {
                            Defaults[.keybinds].append(savedKeybind.convertToWindowAction())
                        }

                    case .erase:
                        Defaults[.keybinds] = []

                        for savedKeybind in importedKeybinds {
                            Defaults[.keybinds].append(savedKeybind.convertToWindowAction())
                        }

                    case .cancel:
                        break
                    }
                }
            }
        } catch {
            print("Error decoding keybinds: \(error.localizedDescription)")

            let alert = NSAlert()
            alert.messageText = "Error Reading Keybinds"
            alert.informativeText = "Make sure the file you selected is in the correct format."
            alert.beginSheetModal(for: NSApplication.shared.mainWindow!)
        }
    }

    private static func showAlertForImportDecision(completion: @escaping (ImportDecision) -> ()) {
        let alert = NSAlert()
        alert.messageText = "Import Keybinds"
        alert.informativeText = "Do you want to merge or erase existing keybinds?"

        alert.addButton(withTitle: "Merge")
        alert.addButton(withTitle: "Erase")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: NSApplication.shared.mainWindow!) { response in
            switch response {
            case .alertFirstButtonReturn: // Merge
                completion(.merge)
            case .alertSecondButtonReturn: // Erase
                completion(.erase)
            default: // Cancel or other cases
                completion(.cancel)
            }
        }
    }

    // Define an enum for the import decision
    enum ImportDecision {
        case merge
        case erase
        case cancel
    }
}
