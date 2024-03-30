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
        var name: String
        var iconName: String
        var unlockTime: Int
        var unlockMessage: String?
        var footer: String?

        static var gregLassaleFooter = String(localized: "This icon was designed by Greg Lassale (@greglassale on 𝕏)")
    }

    private static let icons: [Icon] = [
        Icon(
            name: String(localized: "Classic", comment: "App icon name"),
            iconName: "AppIcon-Classic",
            unlockTime: 0
        ),
        Icon(
            name: String(localized: "Holo", comment: "App icon name"),
            iconName: "AppIcon-Holo",
            unlockTime: 25,
            unlockMessage: String(
                localized: "You've already looped 25 times! As a reward, here's new icon: \(String(localized: "Holo")). Continue to loop more to unlock new icons!"
            )
        ),
        Icon(
            name: String(localized: "Rosé Pine", comment: "App icon name"),
            iconName: "AppIcon-Rose Pine",
            unlockTime: 50
        ),
        Icon(
            name: String(localized: "Meta Loop", comment: "App icon name"),
            iconName: "AppIcon-Meta Loop",
            unlockTime: 100
        ),
        Icon(
            name: String(localized: "Keycap", comment: "App icon name"),
            iconName: "AppIcon-Keycap",
            unlockTime: 200
        ),
        Icon(
            name: String(localized: "White", comment: "App icon name"),
            iconName: "AppIcon-White",
            unlockTime: 400
        ),
        Icon(
            name: String(localized: "Black", comment: "App icon name"),
            iconName: "AppIcon-Black",
            unlockTime: 500
        ),
        Icon(
            name: String(localized: "Simon", comment: "App icon name"),
            iconName: "AppIcon-Simon",
            unlockTime: 1000,
            footer: Icon.gregLassaleFooter
        ),
        Icon(
            name: String(localized: "Neon", comment: "App icon name"),
            iconName: "AppIcon-Neon",
            unlockTime: 1500,
            footer: Icon.gregLassaleFooter
        ),
        Icon(
            name: String(localized: "Synthwave Sunset", comment: "App icon name"),
            iconName: "AppIcon-Synthwave Sunset",
            unlockTime: 2000,
            footer: Icon.gregLassaleFooter
        ),
        Icon(
            name: String(localized: "Black Hole", comment: "App icon name"),
            iconName: "AppIcon-Black Hole",
            unlockTime: 2500,
            footer: Icon.gregLassaleFooter
        ),
        Icon(
            name: String(localized: "Loop Master", comment: "App icon name"),
            iconName: "AppIcon-Loop Master",
            unlockTime: 5000,
            unlockMessage: String(localized: "5000 loops conquered! The universe has witnessed the birth of a Loop Master! Enjoy your well-deserved reward: a brand-new icon!")
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
        print("Setting app icon to: \(icon.name)")
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

            content.title = String(localized: "Loop")

            if let message = icon.unlockMessage {
                content.body = message
            } else {
                content.body = String(localized: "You've unlocked a new icon: \(icon.name)!")
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
