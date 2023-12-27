//
//  Keybind.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-28.
//

import SwiftUI
import Defaults

struct Keybind: Codable, Identifiable, Hashable, Equatable, Defaults.Serializable {
    var id: UUID

    init(
        _ direction: WindowDirection,
        keybind: Set<CGKeyCode>,
        name: String? = nil,
        measureSystem: CustomKeybindMeasureSystem? = nil,
        anchor: CustomKeybindAnchor? = nil,
        width: Double? = nil,
        height: Double? = nil
    ) {
        self.id = UUID()
        self.direction = direction
        self.keybind = keybind
        self.name = name
        self.measureSystem = measureSystem
        self.anchor = anchor
        self.width = width
        self.height = height
    }

    init(_ direction: WindowDirection) {
        self.init(direction, keybind: [])
    }

    var direction: WindowDirection
    var keybind: Set<CGKeyCode>

    // MARK: CUSTOM KEYBINDS
    var name: String?
    var measureSystem: CustomKeybindMeasureSystem?
    var anchor: CustomKeybindAnchor?
    var width: Double?
    var height: Double?

    static func getKeybind(for keybind: Set<CGKeyCode>) -> Keybind? {
        for keybinding in Defaults[.keybinds] where keybinding.keybind == keybind {
            return keybinding
        }
        return nil
    }
}

// MARK: - Import/Export
extension Keybind {
    private struct SavedKeybindFormat: Codable {
        var direction: WindowDirection
        var keybind: Set<CGKeyCode>

        // Custom keybinds
        var name: String?
        var measureSystem: CustomKeybindMeasureSystem?
        var anchor: CustomKeybindAnchor?
        var width: Double?
        var height: Double?

        func convertToKeybind() -> Keybind {
            Keybind(
                direction,
                keybind: keybind,
                name: name,
                measureSystem: measureSystem,
                anchor: anchor,
                width: width,
                height: height
            )
        }
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
                SavedKeybindFormat(
                    direction: $0.direction,
                    keybind: $0.keybind,
                    name: $0.name,
                    measureSystem: $0.measureSystem,
                    anchor: $0.anchor,
                    width: $0.width,
                    height: $0.height
                )
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
                do {
                    try data?.write(to: destUrl)
                } catch {
                    // Handle error
                    print("Error writing to file: \(error)")
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
                do {
                    let jsonString = try String(contentsOf: selectedFileURL)
                    importKeybinds(from: jsonString)
                } catch {
                    // Handle file reading error
                    print("Error reading file: \(error)")
                }
            }
        }
    }

    private static func importKeybinds(from jsonString: String) {
        let decoder = JSONDecoder()

        do {
            let keybindsData = jsonString.data(using: .utf8)!
            let importedKeybinds = try decoder.decode([SavedKeybindFormat].self, from: keybindsData)

            if Defaults[.keybinds].isEmpty {
                for savedKeybind in importedKeybinds {
                    Defaults[.keybinds].append(savedKeybind.convertToKeybind())
                }
            } else {
                showAlertForImportDecision { decision in
                    switch decision {
                    case .merge:
                        for savedKeybind in importedKeybinds where !Defaults[.keybinds].contains(where: {
                            $0.keybind == savedKeybind.keybind && $0.name == savedKeybind.name
                        }) {
                            Defaults[.keybinds].append(savedKeybind.convertToKeybind())
                        }

                    case .erase:
                        Defaults[.keybinds] = []

                        for savedKeybind in importedKeybinds {
                            Defaults[.keybinds].append(savedKeybind.convertToKeybind())
                        }

                    case .cancel:
                        break
                    }
                }
            }
        } catch {
            // Handle decoding error
            print("Error decoding keybinds: \(error)")
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
extension Keybind {
    func previewWindowXOffset(_ parentWidth: CGFloat) -> CGFloat {
        var xLocation = parentWidth * (self.direction.frameMultiplyValues?.minX ?? 0)

        if self.direction == .custom {
            switch self.anchor {
            case .topLeft:
                xLocation = 0
            case .top:
                xLocation = (parentWidth / 2) - (previewWindowWidth(parentWidth) / 2)
            case .topRight:
                xLocation = parentWidth - previewWindowWidth(parentWidth)
            case .right:
                xLocation = parentWidth - previewWindowWidth(parentWidth)
            case .bottomRight:
                xLocation = parentWidth - previewWindowWidth(parentWidth)
            case .bottom:
                xLocation = (parentWidth / 2) - (previewWindowWidth(parentWidth) / 2)
            case .bottomLeft:
                xLocation = 0
            case .left:
                xLocation = 0
            case .center:
                xLocation = (parentWidth / 2) - (previewWindowWidth(parentWidth) / 2)
            default:
                xLocation = 0
            }
        }

        return xLocation
    }

    func previewWindowYOffset(_ parentHeight: CGFloat) -> CGFloat {
        var yLocation = parentHeight * (self.direction.frameMultiplyValues?.minY ?? 0)

        if self.direction == .custom {
            switch self.anchor {
            case .topLeft:
                yLocation = 0
            case .top:
                yLocation = 0
            case .topRight:
                yLocation = 0
            case .right:
                yLocation = (parentHeight / 2) - (previewWindowHeight(parentHeight) / 2)
            case .bottomRight:
                yLocation = parentHeight - previewWindowHeight(parentHeight)
            case .bottom:
                yLocation = parentHeight - previewWindowHeight(parentHeight)
            case .bottomLeft:
                yLocation = parentHeight - previewWindowHeight(parentHeight)
            case .left:
                yLocation = (parentHeight / 2) - (previewWindowHeight(parentHeight) / 2)
            case .center:
                yLocation = (parentHeight / 2) - (previewWindowHeight(parentHeight) / 2)
            default:
                yLocation = 0
            }
        }

        return yLocation
    }

    func previewWindowWidth(_ parentWidth: CGFloat) -> CGFloat {
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

        return width
    }

    func previewWindowHeight(_ parentHeight: CGFloat) -> CGFloat {
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

        return height
    }
}

// MARK: - Custom Keybinds
enum CustomKeybindMeasureSystem: Int, Codable, CaseIterable, Identifiable {
    var id: Self { self }

    case pixels = 0
    case percentage = 1

    var label: Text {
        switch self {
        case .pixels:
            Text("\(Image(systemName: "rectangle.checkered")) Pixels")
        case .percentage:
            Text("\(Image(systemName: "percent")) Percentages")
        }
    }

    var postscript: String {
        switch self {
        case .pixels: "px"
        case .percentage: "%"
        }
    }
}

enum CustomKeybindAnchor: Int, Codable, CaseIterable, Identifiable {
    var id: Self { self }

    case topLeft = 0
    case top = 1
    case topRight = 2
    case right = 3
    case bottomRight = 4
    case bottom = 5
    case bottomLeft = 6
    case left = 7
    case center = 8

    var label: Text {
        switch self {
        case .topLeft: Text("\(Image(systemName: "arrow.up.left")) Top Left")
        case .top: Text("\(Image(systemName: "arrow.up")) Top")
        case .topRight: Text("\(Image(systemName: "arrow.up.right")) Top Right")
        case .right: Text("\(Image(systemName: "arrow.right")) Right")
        case .bottomRight: Text("\(Image(systemName: "arrow.down.right")) Bottom Right")
        case .bottom: Text("\(Image(systemName: "arrow.down")) Bottom")
        case .bottomLeft: Text("\(Image(systemName: "arrow.down.left")) Bottom Left")
        case .left: Text("\(Image(systemName: "arrow.left")) Left")
        case .center: Text("\(Image(systemName: "scope")) Center")
        }
    }
}
