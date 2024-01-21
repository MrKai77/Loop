//
//  IconManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-02-14.
//

import SwiftUI
import Defaults
import UserNotifications

class IconManager {

    struct Icon: Hashable {
        var name: String?
        var iconName: String
        var unlockTime: Int
        var unlockMessage: String?

        func getName() -> String {
            if let name = self.name {
                return name
            } else {
                let prefix = "AppIcon-"
                return iconName.replacingOccurrences(of: prefix, with: "")
            }
        }
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
        print("Setting app icon to: \(icon.getName())")
    }

    static func setAppIcon(to iconName: String) {
        if let targetIcon = icons.first(where: { $0.iconName == iconName }) {
            setAppIcon(to: targetIcon)
        }
    }

    // This function is run at startup to set the current icon to the user's set icon.
    static func refreshCurrentAppIcon() {
        NSWorkspace.shared.setIcon(NSImage(named: Defaults[.currentIcon]), forFile: Bundle.main.bundlePath, options: [])
        NSApp.applicationIconImage = NSImage(named: Defaults[.currentIcon])
    }

    static func checkIfUnlockedNewIcon() {
        guard Defaults[.notificationWhenIconUnlocked] else { return }

        for icon in icons where icon.unlockTime == Defaults[.timesLooped] {
            let content = UNMutableNotificationContent()

            content.title = "Loop"

            if let message = icon.unlockMessage {
                content.body = message
            } else {
                content.body = "You've unlocked a new icon: \(icon.getName())!"
            }

            if let data = NSImage(named: icon.iconName)?.tiffRepresentation,
               let attachment = UNNotificationAttachment.create(NSData(data: data)) {
                content.attachments = [attachment]
                content.userInfo = ["icon": icon.iconName]
            }

            content.categoryIdentifier = "icon_unlocked"

            AppDelegate.sendNotification(content)
        }
    }

    static var currentAppIcon: Icon {
        return icons.first(where: { $0.iconName == Defaults[.currentIcon] }) ?? icons.first!
    }
}
