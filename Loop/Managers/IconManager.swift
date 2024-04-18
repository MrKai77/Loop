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
        var footer: String?

        func getName() -> String {
            if let name = self.name {
                return name
            }

            let prefix = "AppIcon-"
            return iconName.replacingOccurrences(of: prefix, with: "")
        }

        static var gregLassaleFooter = String(
            localized: .init(
                "Greg Lassale Footer",
                defaultValue: "This icon was designed by Greg Lassale (@greglassale on 𝕏)"
            )
        )
    }

    private static let icons: [Icon] = [
        Icon(
            name: .init(localized: .init("Icon Name: Classic", defaultValue: "Classic")),
            iconName: "AppIcon-Classic",
            unlockTime: 0
        ),
        Icon(
            name: .init(localized: .init("Icon Name: Holo", defaultValue: "Holo")),
            iconName: "AppIcon-Holo",
            unlockTime: 25,
            unlockMessage: .init(
                localized: .init(
                    "Icon Unlock Message: Holo",
                    defaultValue: """
You've already looped 25 times! As a reward, here's new icon: \(.init(localized: .init("Icon Name: Holo", defaultValue: "Holo"))). Continue to loop more to unlock new icons!
"""
                )
            )
        ),
        Icon(
            name: .init(localized: .init("Icon Name: Rosé Pine", defaultValue: "Rosé Pine")),
            iconName: "AppIcon-Rose Pine",
            unlockTime: 50
        ),
        Icon(
            name: .init(localized: .init("Icon Name: Meta Loop", defaultValue: "Meta Loop")),
            iconName: "AppIcon-Meta Loop",
            unlockTime: 100
        ),
        Icon(
            name: .init(localized: .init("Icon Name: Keycap", defaultValue: "Keycap")),
            iconName: "AppIcon-Keycap",
            unlockTime: 200
        ),
        Icon(
            name: .init(localized: .init("Icon Name: White", defaultValue: "White")),
            iconName: "AppIcon-White",
            unlockTime: 400
        ),
        Icon(
            name: .init(localized: .init("Icon Name: Black", defaultValue: "Black")),
            iconName: "AppIcon-Black",
            unlockTime: 500
        ),

        Icon(
            name: .init(localized: .init("Icon Name: Simon", defaultValue: "Simon")),
            iconName: "AppIcon-Simon",
            unlockTime: 1000,
            footer: Icon.gregLassaleFooter
        ),
        Icon(
            name: .init(localized: .init("Icon Name: Neon", defaultValue: "Neon")),
            iconName: "AppIcon-Neon",
            unlockTime: 1500,
            footer: Icon.gregLassaleFooter
        ),
        Icon(
            name: .init(localized: .init("Icon Name: Synthwave Sunset", defaultValue: "Synthwave Sunset")),
            iconName: "AppIcon-Synthwave Sunset",
            unlockTime: 2000, footer: Icon.gregLassaleFooter
        ),
        Icon(
            name: .init(localized: .init("Icon Name: Black Hole", defaultValue: "Black Hole")),
            iconName: "AppIcon-Black Hole",
            unlockTime: 2500, footer: Icon.gregLassaleFooter
        ),

        Icon(
            name: .init(localized: .init("Icon Name: Loop Master", defaultValue: "Loop Master")),
            iconName: "AppIcon-Loop Master",
            unlockTime: 5000,
            unlockMessage: .init(
                localized: .init(
                    "Icon Unlock Message: Loop Master",
                    defaultValue: """
5000 loops conquered! The universe has witnessed the birth of a Loop master! Enjoy your well-deserved reward: a brand-new icon!
"""
                )
            )
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

            content.title = Bundle.main.appName

            if let message = icon.unlockMessage {
                content.body = message
            } else {
                content.body = .init(
                    localized: .init(
                        "Icon Unlock Message",
                        defaultValue: "You've unlocked a new icon: \(icon.getName())!"
                    )
                )
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
        return icons.first {
            $0.iconName == Defaults[.currentIcon]
        } ?? icons.first!
    }
}
