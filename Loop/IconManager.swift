//
//  IconManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-02-14.
//

import Cocoa
import Defaults
import DSFDockTile

struct Icon {
    static let defaultIcon = "AppIcon-Default"
    static let donut = "AppIcon-Donut"
    static let sciFi = "AppIcon-Scifi"
    static let roséPine = "AppIcon-Rosé Pine"
    
    static func nameWithoutPrefix(name: String) -> String {
        let prefix = "AppIcon-"
        return name.replacingOccurrences(of: prefix, with: "")
    }
}

class IconManager {
    
    let timesThatUnlockNewIcons = [50, 100]
    
    func returnUnlockedIcons() -> [String] {
        var returnValue = [Icon.defaultIcon]
        
        if Defaults[.timesLooped] >= timesThatUnlockNewIcons[0] {
            returnValue.append(Icon.sciFi)
        }
        if Defaults[.timesLooped] >= timesThatUnlockNewIcons[1] {
            returnValue.append(Icon.roséPine)
        }
        
        return returnValue
    }
    
    func setAppIcon(to icon: String) {
        let loopDockTile = DSFDockTile.Image()
        
        loopDockTile.display(NSImage(named: icon)!)
        let alert = NSAlert()
        alert.messageText = "\(Bundle.main.appName)"
        alert.informativeText = "Current icon is now \(Icon.nameWithoutPrefix(name: icon))!"
        alert.icon = NSImage(named: icon)
        alert.runModal()
        
        Defaults[.currentIcon] = icon
    }
    
    func setCurrentAppIcon() {
        let loopDockTile = DSFDockTile.Image()
        loopDockTile.display(NSImage(named: Defaults[.currentIcon])!)
    }
    
    func didUnlockNewIcon() {
        if timesThatUnlockNewIcons.contains(Defaults[.timesLooped]) {
            let alert = NSAlert()
            var iconToChangeTo = ""

            switch(Defaults[.timesLooped]) {
            case timesThatUnlockNewIcons[0]:
                iconToChangeTo = Icon.sciFi
                alert.icon = NSImage(named: iconToChangeTo)
                alert.messageText = "You've unlocked a new icon: \(Icon.nameWithoutPrefix(name: iconToChangeTo))!"
                
            case timesThatUnlockNewIcons[1]:
                iconToChangeTo = Icon.roséPine
                alert.icon = NSImage(named: iconToChangeTo)
                alert.messageText = "You've unlocked a new icon: \(Icon.nameWithoutPrefix(name: iconToChangeTo))!"

            default:
                return
            }

            alert.informativeText = "Would you like to set this as \(Bundle.main.appName)'s new icon?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Yes").keyEquivalent = "\r"
            alert.addButton(withTitle: "No")

            NSApp.activate(ignoringOtherApps: true)
            let response = alert.runModal()

            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                setAppIcon(to: iconToChangeTo)
            }
        }
    }
}
