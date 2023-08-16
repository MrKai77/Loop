//
//  IconManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-02-14.
//

import SwiftUI
import Defaults

class IconManager {

    struct Icon {
        var name: String
        var unlockTime: Int
        var unlockMessage: String?
    }

    let icons: [Icon] = [
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
            name: "AppIcon-Loop Master",
            unlockTime: 100,
            unlockMessage: ("100 loops conquered! "
                + "The universe has witnessed the birth of a Loop Master! "
                + "Enjoy your well-deserved reward: a brand-new icon!")
        )
    ]

    func nameWithoutPrefix(name: String) -> String {
        let prefix = "AppIcon-"
        return name.replacingOccurrences(of: prefix, with: "")
    }

    func returnUnlockedIcons() -> [String] {
        var returnValue: [String] = []
        for icon in icons where icon.unlockTime <= Defaults[.timesLooped] {
            returnValue.append(icon.name)
        }
        return returnValue.reversed()
    }

    func setAppIcon(to icon: Icon) {
        NSWorkspace.shared.setIcon(NSImage(named: icon.name), forFile: Bundle.main.bundlePath, options: [])
        NSApp.applicationIconImage = NSImage(named: icon.name)

        let alert = NSAlert()
        alert.messageText = "\(Bundle.main.appName)"
        alert.informativeText = "Current icon is now \(nameWithoutPrefix(name: icon.name))!"
        alert.icon = NSImage(named: icon.name)
        alert.runModal()

        Defaults[.currentIcon] = icon.name
    }

    // This function is run at startup to set the current icon to the user's set icon.
    func restoreCurrentAppIcon() {
        NSWorkspace.shared.setIcon(NSImage(named: Defaults[.currentIcon]), forFile: Bundle.main.bundlePath, options: [])
        NSApp.applicationIconImage = NSImage(named: Defaults[.currentIcon])
    }

    func checkIfUnlockedNewIcon() {
        for icon in icons where icon.unlockTime == Defaults[.timesLooped] {
            if #available(macOS 14.0, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }

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

            NSApp.activate(ignoringOtherApps: true)
            let response = alert.runModal()

            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                setAppIcon(to: icon)
            }
        }
    }
}
