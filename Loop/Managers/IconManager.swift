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
        var name: String?
        var iconName: String
        var unlockTime: Int
        var unlockMessage: String?
    }

    private static let icons: [Icon] = [
        Icon(iconName: "AppIcon-Classic", unlockTime: 0),
        Icon(
            iconName: "AppIcon-Holo",
            unlockTime: 25,
            unlockMessage: ("You've already looped 25 times! "
                + "As a reward, here's new icon: Holo. "
                + "Continue to loop more to unlock new icons!")
        ),
        Icon(
            name: "Rosé Pine",
            iconName: "AppIcon-Rose Pine",
            unlockTime: 50
        ),
        Icon(iconName: "AppIcon-Meta Loop", unlockTime: 100),
        Icon(iconName: "AppIcon-Keycap", unlockTime: 200),
        Icon(iconName: "AppIcon-White", unlockTime: 300),
        Icon(iconName: "AppIcon-Black", unlockTime: 400),
        Icon(
            iconName: "AppIcon-Loop Master",
            unlockTime: 1000,
            unlockMessage: ("1000 loops conquered! "
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
        Defaults[.currentIcon] = icon.iconName
        self.refreshCurrentAppIcon()

        let alert = NSAlert()
        alert.messageText = "\(Bundle.main.appName)"
        alert.informativeText = "Current icon is now \(icon.name ??  nameWithoutPrefix(name: icon.iconName))!"
        alert.icon = NSImage(named: icon.iconName)
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
            alert.icon = NSImage(named: icon.iconName)
            if let message = icon.unlockMessage {
                alert.messageText = message
            } else {
                alert.messageText = "You've unlocked a new icon: \(nameWithoutPrefix(name: icon.iconName))!"
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
        return icons.first(where: { $0.iconName == Defaults[.currentIcon] }) ?? icons.first!
    }
}
