//
//  IconManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-02-14.
//

import Defaults
import Luminare
import OSLog
import SwiftUI
import UserNotifications

enum IconManager {
    private static let logger = Logger(category: "IconManager")

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
        logger.info("Setting app icon to: \(icon.name)")
    }

    static func setAppIcon(to assetName: String) {
        if let targetIcon = Icon.all.first(where: { $0.assetName == assetName }) {
            setAppIcon(to: targetIcon)
        }
    }

    // This function is run at startup to set the current icon to the user's set icon.
    static func refreshCurrentAppIcon() {
        guard let image = NSImage(named: Defaults[.currentIcon]) else {
            logger.error("Failed to load icon: \(Defaults[.currentIcon])")
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
