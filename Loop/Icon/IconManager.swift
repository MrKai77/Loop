//
//  IconManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-02-14.
//

import Defaults
import Luminare
import Scribe
import SwiftUI
import UserNotifications

enum IconManager {
    static func returnUnlockedIcons() -> [Icon] {
        var returnValue: [Icon] = []
        for icon in Icon.all where icon.unlockTime <= Defaults[.timesLooped] {
            returnValue.append(icon)
        }

        return returnValue.reversed()
    }

    static func setAppIcon(to icon: Icon) {
        Defaults[.currentIcon] = icon.assetName
        refreshCurrentAppIcon()
    }

    static func setAppIcon(to assetName: String) {
        if let targetIcon = Icon.all.first(where: { $0.assetName == assetName }) {
            setAppIcon(to: targetIcon)
        }
    }

    // This function is run at startup to set the current icon to the user's set icon.
    static func refreshCurrentAppIcon() {
        let iconName = Defaults[.currentIcon]

        guard let image = NSImage(named: iconName) else {
            Log.error("Failed to load icon: \(iconName)", category: .iconManager)
            return
        }

        #if !DEBUG
            // Changing the app's actual icon on a developer build can cause Xcode to have incremental codesign issues.
            // To prevent this, we only change the icon on release builds.
            NSWorkspace.shared.setIcon(image, forFile: Bundle.main.bundlePath, options: [])
        #endif

        if Defaults[.currentIcon] == Icon.default.assetName {
            NSApp.applicationIconImage = nil
        } else {
            NSApp.applicationIconImage = image
        }

        Log.info("Set app icon to: \(iconName)", category: .iconManager)
    }

    static func checkIfUnlockedNewIcon() {
        guard Defaults[.notificationWhenIconUnlocked] else { return }

        for icon in Icon.all where icon.unlockTime == Defaults[.timesLooped] {
            let content = UNMutableNotificationContent()

            content.title = Bundle.main.appName

            if let message = icon.unlockMessage {
                content.body = message
            } else {
                content.body = String(
                    localized: "Icon Unlock Message",
                    defaultValue: "You've unlocked a new icon: \(icon.name)!",
                    comment: "Default message shown when a new icon is unlocked"
                )
            }

            if let data = NSImage(named: icon.assetName)?.tiffRepresentation,
               let attachment = UNNotificationAttachment.create(NSData(data: data)) {
                content.attachments = [attachment]
                content.userInfo = ["icon": icon.assetName]
            }

            content.categoryIdentifier = "icon_unlocked"

            AppDelegate.sendNotification(content)
        }
    }

    static var currentAppIcon: Icon {
        Icon.all.first {
            $0.assetName == Defaults[.currentIcon]
        } ?? Icon.all.first!
    }
}
