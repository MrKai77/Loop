//
//  IconManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-02-14.
//

import Defaults
import Luminare
import SwiftUI
import UserNotifications

class IconManager {
    static func returnUnlockedIcons() -> [Icon] {
        var returnValue: [Icon] = []
        for icon in Icon.all where icon.unlockTime <= Defaults[.timesLooped] {
            returnValue.append(icon)
        }

        return returnValue.reversed()
    }

    static func setAppIcon(to icon: Icon) {
        Defaults[.currentIcon] = icon.iconName
        refreshCurrentAppIcon()
        print("Setting app icon to: \(icon.name)")
    }

    static func setAppIcon(to iconName: String) {
        if let targetIcon = Icon.all.first(where: { $0.iconName == iconName }) {
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

        for icon in Icon.all where icon.unlockTime == Defaults[.timesLooped] {
            let content = UNMutableNotificationContent()

            content.title = Bundle.main.appName

            if let message = icon.unlockMessage {
                content.body = message
            } else {
                content.body = .init(
                    localized: .init(
                        "Icon Unlock Message",
                        defaultValue: "You've unlocked a new icon: \(icon.name)!"
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
        Icon.all.first {
            $0.iconName == Defaults[.currentIcon]
        } ?? Icon.all.first!
    }
}
