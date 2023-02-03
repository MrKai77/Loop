//
//  LoopMenubarController.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import Cocoa
import KeyboardShortcuts

struct resizeWindowMenuItem {
    var divider: Bool?
    var title: String?
    var selector: Selector?
    var shortcut: KeyboardShortcuts.Name?
}

class LoopMenubarController {
    
    let resizeWindowMenuItems = [
        resizeWindowMenuItem(title: "Maximize", selector: #selector(resizeWindowMaximize), shortcut: .resizeMaximize),
        resizeWindowMenuItem(divider: true),
        resizeWindowMenuItem(title: "Top Half", selector: #selector(resizeWindowTopHalf), shortcut: .resizeTopHalf),
        resizeWindowMenuItem(title: "Bottom Half", selector: #selector(resizeWindowBottomHalf), shortcut: .resizeBottomHalf),
        resizeWindowMenuItem(title: "Right Half", selector: #selector(resizeWindowRightHalf), shortcut: .resizeRightHalf),
        resizeWindowMenuItem(title: "Left Half", selector: #selector(resizeWindowLeftHalf), shortcut: .resizeLeftHalf),
        resizeWindowMenuItem(divider: true),
        resizeWindowMenuItem(title: "Top Right Quarter", selector: #selector(resizeWindowTopRightQuarter), shortcut: .resizeTopRightQuarter),
        resizeWindowMenuItem(title: "Top Left Quarter", selector: #selector(resizeWindowTopLeftQuarter), shortcut: .resizeTopLeftQuarter),
        resizeWindowMenuItem(title: "Bottom Right Quarter", selector: #selector(resizeWindowBottomRightQuarter), shortcut: .resizeBottomRightQuarter),
        resizeWindowMenuItem(title: "Bottom Left Quarter", selector: #selector(resizeWindowBottomLeftQuarter), shortcut: .resizeBottomLeftQuarter),
        resizeWindowMenuItem(divider: true),
        resizeWindowMenuItem(title: "Right Third", selector: #selector(resizeWindowRightThird), shortcut: .resizeRightThird),
        resizeWindowMenuItem(title: "Right Two Thirds", selector: #selector(resizeWindowRightTwoThirds), shortcut: .resizeRightTwoThirds),
        resizeWindowMenuItem(title: "Center Third", selector: #selector(resizeWindowRLCenterThird), shortcut: .resizeRLCenterThird),
        resizeWindowMenuItem(title: "Left Two Thirds", selector: #selector(resizeWindowLeftTwoThirds), shortcut: .resizeLeftTwoThirds),
        resizeWindowMenuItem(title: "Left Third", selector: #selector(resizeWindowLeftThird), shortcut: .resizeLeftThird)
    ]
    
    let windowResizer = WindowResizer()
    private var statusItem: NSStatusItem!
    
    func show() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(named: NSImage.Name("menubarIcon"))
        
        let loopMenu = NSMenu()
        
        let resizeWindow = NSMenuItem(title: "Resize Window", action: nil, keyEquivalent: "")
        resizeWindow.submenu = NSMenu()
        
        for item in resizeWindowMenuItems {
            if item.divider != nil {
                resizeWindow.submenu?.addItem(NSMenuItem.separator())
            } else {
                let menuItem = NSMenuItem(title: item.title!, action: item.selector, keyEquivalent: "")
                menuItem.setShortcut(for: item.shortcut)
                menuItem.target = self
                
                resizeWindow.submenu?.addItem(menuItem)
            }
        }
        
        loopMenu.addItem(resizeWindow)
        loopMenu.addItem(NSMenuItem.separator())
        if #available(macOS 13, *) {
            loopMenu.addItem(withTitle: "Settings", action: #selector(self.openSettings), keyEquivalent: ",").target = self
        } else {
            loopMenu.addItem(withTitle: "Preferences", action: #selector(self.openSettings), keyEquivalent: ",").target = self
        }
        loopMenu.addItem(withTitle: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")
        
        statusItem.menu = loopMenu
    }
    
    @objc func resizeWindowMaximize() {
        self.windowResizer.resizeFrontmostWindowWithDirection(.maximize)
    }
    
    @objc func resizeWindowTopHalf() {
        self.windowResizer.resizeFrontmostWindowWithDirection(.topHalf)
    }
    @objc func resizeWindowBottomHalf() {
        self.windowResizer.resizeFrontmostWindowWithDirection(.bottomHalf)
    }
    @objc func resizeWindowRightHalf() {
        self.windowResizer.resizeFrontmostWindowWithDirection(.rightHalf)
    }
    @objc func resizeWindowLeftHalf() {
        self.windowResizer.resizeFrontmostWindowWithDirection(.leftHalf)
    }
    
    @objc func resizeWindowTopRightQuarter() {
        self.windowResizer.resizeFrontmostWindowWithDirection(.topRightQuarter)
    }
    @objc func resizeWindowTopLeftQuarter() {
        self.windowResizer.resizeFrontmostWindowWithDirection(.topLeftQuarter)
    }
    @objc func resizeWindowBottomRightQuarter() {
        self.windowResizer.resizeFrontmostWindowWithDirection(.bottomRightQuarter)
    }
    @objc func resizeWindowBottomLeftQuarter() {
        self.windowResizer.resizeFrontmostWindowWithDirection(.bottomLeftQuarter)
    }
    
    @objc func resizeWindowRightThird() {
        self.windowResizer.resizeFrontmostWindowWithDirection(.rightThird)
    }
    @objc func resizeWindowRightTwoThirds() {
        self.windowResizer.resizeFrontmostWindowWithDirection(.rightTwoThirds)
    }
    @objc func resizeWindowRLCenterThird() {
        self.windowResizer.resizeFrontmostWindowWithDirection(.RLcenterThird)
    }
    @objc func resizeWindowLeftTwoThirds() {
        self.windowResizer.resizeFrontmostWindowWithDirection(.leftTwoThirds)
    }
    @objc func resizeWindowLeftThird() {
        self.windowResizer.resizeFrontmostWindowWithDirection(.leftThird)
    }
    
    @objc func openSettings() {
        if #available(macOS 13, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
