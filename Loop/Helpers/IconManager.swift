//
//  IconManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-02-14.
//

import SwiftUI
import Defaults

class IconManager {
    
    // Icon name, times looped needed to unlock it
    let icons: [String: Int] = [
        "AppIcon-Default": 0,
        "AppIcon-Scifi": 25,
        "AppIcon-Rosé Pine": 50,
    ]
    
    public func nameWithoutPrefix(name: String) -> String {
        let prefix = "AppIcon-"
        return name.replacingOccurrences(of: prefix, with: "")
    }
    
    public func returnUnlockedIcons() -> [String] {
        var returnValue: [String] = []
        for (icon, unlockTimes) in icons where unlockTimes <= Defaults[.timesLooped] {
            returnValue.append(icon)
        }
        return returnValue.reversed()
    }
    
    public func setAppIcon(to icon: String) {
        NSWorkspace.shared.setIcon(NSImage(named: icon), forFile: Bundle.main.bundlePath, options: [])
        NSApp.applicationIconImage = NSImage(named: icon)
        
        let alert = NSAlert()
        alert.messageText = "\(Bundle.main.appName)"
        alert.informativeText = "Current icon is now \(nameWithoutPrefix(name: icon))!"
        alert.icon = NSImage(named: icon)
        alert.runModal()
        
        Defaults[.currentIcon] = icon
    }
    
    // This function is run at startup to set the current icon to the user's set icon.
    public func setCurrentAppIcon() {
        NSWorkspace.shared.setIcon(NSImage(named: Defaults[.currentIcon]), forFile: Bundle.main.bundlePath, options: [])
        NSApp.applicationIconImage = NSImage(named: Defaults[.currentIcon])
    }
    
    public func checkIfUnlockedNewIcon() {
        for (icon, unlockTimes) in icons where unlockTimes == Defaults[.timesLooped] {
            let alert = NSAlert()
            alert.icon = NSImage(named: icon)
            alert.messageText = "You've unlocked a new icon: \(nameWithoutPrefix(name: icon))!"
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
