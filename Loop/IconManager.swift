//
//  IconManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-02-14.
//

import Cocoa
import Defaults

class IconManager {
    let timesThatUnlockNewIcons = [50, 100]
    
    func changeIcon(_ icon: String) {
        let alert = NSAlert()
        
        switch(icon) {
        case "Donut":
            NSWorkspace.shared.setIcon(NSImage(named: "AppIcon-Donut")!, forFile: Bundle.main.bundleURL.path, options: [])
            alert.icon = NSImage(named: "AppIcon-Donut")
        case "Sci-fi":
            NSWorkspace.shared.setIcon(NSImage(named: "AppIcon-Scifi")!, forFile: Bundle.main.bundleURL.path, options: [])
            alert.icon = NSImage(named: "AppIcon-Scifi")
            
        default:
            NSWorkspace.shared.setIcon(NSImage(named: "AppIcon")!, forFile: Bundle.main.bundleURL.path, options: [])
            alert.icon = NSImage(named: "AppIcon")
        }

        alert.messageText = "\(Bundle.main.appName)"
        alert.informativeText = "Current icon is now \(icon)!"
        alert.runModal()
    }
    
    func didUnlockNewIcon() {
        if timesThatUnlockNewIcons.contains(Defaults[.timesLooped]) {
            let alert = NSAlert()
            var iconToChangeTo = ""
             
            switch(Defaults[.timesLooped]) {
            case timesThatUnlockNewIcons[0]:
                iconToChangeTo = "Donut"
                alert.icon = NSImage(named: "AppIcon-Donut")
                alert.messageText = "You've unlocked a new icon: Donut!"
                
            case timesThatUnlockNewIcons[1]:
                iconToChangeTo = "Sci-fi"
                alert.icon = NSImage(named: "AppIcon-Scifi")
                alert.messageText = "You've unlocked a new icon: Sci-fi!"
                
            default:
                return
            }
            
            alert.informativeText = "Would you like to set this as \(Bundle.main.appName)'s new icon?"
            
            alert.alertStyle = .informational
            
            alert.addButton(withTitle: "Yes").keyEquivalent = "\r"
            alert.addButton(withTitle: "No")
            
            NSApp.activate(ignoringOtherApps: true)
            let response = alert.runModal()
            
            if (response == NSApplication.ModalResponse.alertFirstButtonReturn) {
                self.changeIcon(iconToChangeTo)
            }
        }
    }
}
