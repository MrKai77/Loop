//
//  Keybind.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-28.
//

import SwiftUI
import Defaults

struct WindowAction: Codable, Identifiable, Hashable, Equatable, Defaults.Serializable {
    var id: UUID

    init(
        _ direction: WindowDirection,
        keybind: Set<CGKeyCode>,
        name: String? = nil,
        measureSystem: CustomWindowActionMeasureSystem? = nil,
        anchor: CustomWindowActionAnchor? = nil,
        width: Double? = nil,
        height: Double? = nil,
        cycle: [WindowAction]? = nil
    ) {
        self.id = UUID()
        self.direction = direction
        self.keybind = keybind
        self.name = name
        self.measureSystem = measureSystem
        self.anchor = anchor
        self.width = width
        self.height = height
        self.cycle = cycle
    }

    init(_ direction: WindowDirection) {
        self.init(direction, keybind: [])
    }

    init(_ cycle: [WindowAction]?) {
        self.init(.cycle, keybind: [], cycle: cycle)
    }

    var direction: WindowDirection
    var keybind: Set<CGKeyCode>

    // MARK: CUSTOM KEYBINDS
    var name: String?
    var measureSystem: CustomWindowActionMeasureSystem?
    var anchor: CustomWindowActionAnchor?
    var width: Double?
    var height: Double?

    var cycle: [WindowAction]?

    static func getAction(for keybind: Set<CGKeyCode>) -> WindowAction? {
        for keybinding in Defaults[.keybinds] where keybinding.keybind == keybind {
            return keybinding
        }
        return nil
    }
}

// MARK: - Import/Export
extension WindowAction {
    private struct SavedWindowActionFormat: Codable {
        var direction: WindowDirection
        var keybind: Set<CGKeyCode>

        // Custom keybinds
        var name: String?
        var measureSystem: CustomWindowActionMeasureSystem?
        var anchor: CustomWindowActionAnchor?
        var width: Double?
        var height: Double?

        var cycle: [SavedWindowActionFormat]?

        func convertToWindowAction() -> WindowAction {
            WindowAction(
                direction,
                keybind: keybind,
                name: name,
                measureSystem: measureSystem,
                anchor: anchor,
                width: width,
                height: height,
                cycle: cycle?.map { $0.convertToWindowAction() }
            )
        }
    }

    private func convertToSavedWindowActionFormat() -> SavedWindowActionFormat {
        SavedWindowActionFormat(
            direction: direction,
            keybind: keybind,
            name: name,
            measureSystem: measureSystem,
            anchor: anchor,
            width: width,
            height: height,
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
            print("Error encoding keybinds: \(error)")
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
                        print("Error writing to file: \(error)")
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
                        print("Error reading file: \(error)")
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
            print("Error decoding keybinds: \(error)")

            let alert = NSAlert()
            alert.messageText = "Error Reading Keybinds"
            alert.informativeText = "Make sure the file you selected is in the correct format."
            alert.beginSheetModal(for: NSApplication.shared.mainWindow!)
        }
    }

    private static func showAlertForImportDecision(completion: @escaping (ImportDecision) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Import Keybinds"
        alert.informativeText = "Do you want to merge or erase existing keybinds?"

        alert.addButton(withTitle: "Merge")
        alert.addButton(withTitle: "Erase")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: NSApplication.shared.mainWindow!) { response in
            switch response {
            case .alertFirstButtonReturn:  // Merge
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

// MARK: - Preview Window
extension WindowAction {
    func previewWindowXOffset(_ parentWidth: CGFloat, _ window: Window?) -> CGFloat {
        var xLocation = parentWidth * (self.direction.frameMultiplyValues?.minX ?? 0)
        let previewWidth = previewWindowWidth(parentWidth, window)

        if self.direction == .custom {
            switch self.anchor {
            case .topLeft:
                xLocation = 0
            case .top:
                xLocation = (parentWidth / 2) - (previewWidth / 2)
            case .topRight:
                xLocation = parentWidth - previewWidth
            case .right:
                xLocation = parentWidth - previewWidth
            case .bottomRight:
                xLocation = parentWidth - previewWidth
            case .bottom:
                xLocation = (parentWidth / 2) - (previewWidth / 2)
            case .bottomLeft:
                xLocation = 0
            case .left:
                xLocation = 0
            case .center:
                xLocation = (parentWidth / 2) - (previewWidth / 2)
            case .macOSCenter:
                xLocation = (parentWidth / 2) - (previewWidth / 2)
            default:
                xLocation = 0
            }
        }

        if self.direction == .center || self.direction == .macOSCenter {
            xLocation = (parentWidth / 2) - (previewWidth / 2)
        }

        return xLocation
    }

    func previewWindowYOffset(_ parentHeight: CGFloat, _ window: Window?) -> CGFloat {
        var yLocation = parentHeight * (self.direction.frameMultiplyValues?.minY ?? 0)
        let previewHeight = previewWindowHeight(parentHeight, window)

        if self.direction == .custom {
            switch self.anchor {
            case .topLeft:
                yLocation = 0
            case .top:
                yLocation = 0
            case .topRight:
                yLocation = 0
            case .right:
                yLocation = (parentHeight / 2) - (previewHeight / 2)
            case .bottomRight:
                yLocation = parentHeight - previewHeight
            case .bottom:
                yLocation = parentHeight - previewHeight
            case .bottomLeft:
                yLocation = parentHeight - previewHeight
            case .left:
                yLocation = (parentHeight / 2) - (previewHeight / 2)
            case .center:
                yLocation = (parentHeight / 2) - (previewHeight / 2)
            case .macOSCenter:
                let yOffset = WindowEngine.getMacOSCenterYOffset(previewHeight, screenHeight: parentHeight)
                yLocation = (parentHeight / 2) - (previewHeight / 2) + yOffset
            default:
                yLocation = 0
            }
        }

        if self.direction == .center {
            yLocation = (parentHeight / 2) - (previewHeight / 2)
        }

        if self.direction == .macOSCenter {
            let yOffset = WindowEngine.getMacOSCenterYOffset(previewHeight, screenHeight: parentHeight)
            yLocation = (parentHeight / 2) - (previewHeight / 2) + yOffset
        }

        return yLocation
    }

    func previewWindowWidth(_ parentWidth: CGFloat, _ window: Window?) -> CGFloat {
        var width = parentWidth * (self.direction.frameMultiplyValues?.width ?? 0)

        if self.direction == .custom {
            switch self.measureSystem {
            case .pixels:
                width = self.width ?? 0
            case .percentage:
                width =  parentWidth * ((self.width ?? 100) / 100)
            default:
                width = 0
            }
        }

        if self.direction == .center || self.direction == .macOSCenter, let window = window {
            width = window.frame.width
        }

        return width
    }

    func previewWindowHeight(_ parentHeight: CGFloat, _ window: Window?) -> CGFloat {
        var height = parentHeight * (self.direction.frameMultiplyValues?.height ?? 0)

        if self.direction == .custom {
            switch self.measureSystem {
            case .pixels:
                height = self.height ?? 0
            case .percentage:
                height =  parentHeight * ((self.height ?? 100) / 100)
            default:
                height = 0
            }
        }

        if self.direction == .center || self.direction == .macOSCenter, let window = window {
            height = window.frame.height
        }

        return height
    }
}
