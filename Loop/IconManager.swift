//
//  IconManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-02-14.
//

import Cocoa
import Defaults

class IconManager {
    func changeIcon(_ icon: String) {
        let alert = NSAlert()
        
        switch(icon) {
        case "Loop":
            NSApplication.shared.applicationIconImage = nil
            Defaults[.currentIcon] = "Loop"
            alert.icon = NSImage(named: "AppIcon")
        case "Donut":
            NSApplication.shared.applicationIconImage = NSImage(named: "AppIcon-Donut")
            Defaults[.currentIcon] = "Donut"
            alert.icon = NSImage(named: "AppIcon-Donut")
        default:
            NSApplication.shared.applicationIconImage = nil
            Defaults[.currentIcon] = "Loop"
            alert.icon = NSImage(named: "AppIcon")
        }

        alert.messageText = "\(Bundle.main.appName)"
        alert.informativeText = "Current icon is now \(icon)!"
        alert.runModal()
    }
}
