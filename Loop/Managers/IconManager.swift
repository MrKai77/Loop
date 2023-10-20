//
//  IconManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-02-14.
//

import SwiftUI
import Defaults

class IconManager {

    struct Icon: Hashable {
        var name: String
        var unlockTime: Int
        var unlockMessage: String?
    }

    private static let icons: [Icon] = [
        Icon(
            name: "AppIcon-Classic",
            unlockTime: 0
        ),
        Icon(
            name: "AppIcon-Sci-fi",
            unlockTime: 25
        ),
        Icon(
            name: "AppIcon-Rosé Pine",
            unlockTime: 50
        ),
        Icon(
            name: "AppIcon-Metaloop",
            unlockTime: 100
        ),
        Icon(
            name: "AppIcon-Loop Master",
            unlockTime: 500,
            unlockMessage: ("500 loops conquered! "
                + "The universe has witnessed the birth of a Loop Master! "
                + "Enjoy your well-deserved reward: a brand-new icon!")
        )
    ]

    static func nameWithoutPrefix(name: String) -> String {
        let prefix = "AppIcon-"
        return name.replacingOccurrences(of: prefix, with: "")
    }

    static func returnUnlockedIcons() -> [Icon] {
        var returnValue: [Icon] = []
        for icon in icons where icon.unlockTime <= Defaults[.timesLooped] {
            returnValue.append(icon)
        }
        return returnValue.reversed()
    }

    static func setAppIcon(to icon: Icon) {
        Defaults[.currentIcon] = icon.name
        self.refreshCurrentAppIcon()

        let alert = NSAlert()
        alert.messageText = "\(Bundle.main.appName)"
        alert.informativeText = "Current icon is now \(nameWithoutPrefix(name: icon.name))!"
        alert.icon = NSImage(named: icon.name)
        alert.runModal()
    }

    // This function is run at startup to set the current icon to the user's set icon.
    static func refreshCurrentAppIcon() {
        NSWorkspace.shared.setIcon(NSImage(named: Defaults[.currentIcon]), forFile: Bundle.main.bundlePath, options: [])
        NSApp.applicationIconImage = NSImage(named: Defaults[.currentIcon])
    }

    static func checkIfUnlockedNewIcon() {
        for icon in icons where icon.unlockTime == Defaults[.timesLooped] {
            NSApp.setActivationPolicy(.regular)

            let alert = NSAlert()
            alert.icon = NSImage(named: icon.name)
            if let message = icon.unlockMessage {
                alert.messageText = message
            } else {
                alert.messageText = "You've unlocked a new icon: \(nameWithoutPrefix(name: icon.name))!"
            }
            alert.informativeText = "Would you like to set this as \(Bundle.main.appName)'s new icon?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Yes").keyEquivalent = "\r"
            alert.addButton(withTitle: "No")

            let response = alert.runModal()
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                setAppIcon(to: icon)
            }
        }
    }

    static var currentAppIcon: Icon {
        return icons.first(where: { $0.name == Defaults[.currentIcon] }) ?? icons.first!
    }
}
