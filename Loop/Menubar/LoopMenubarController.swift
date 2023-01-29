//
//  LoopMenubarController.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import Cocoa

class LoopMenubarController {
    
    let windowResizer = WindowResizer()
    private var statusItem: NSStatusItem!
    
    func show() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name("menubarIcon"))
        }
        
        let resizeWindow = NSMenuItem(title: "Resize Window", action: nil, keyEquivalent: "")
        resizeWindow.submenu = NSMenu()
        
        resizeWindow.submenu?.addItem(withTitle: "Maximize", action: #selector(resizeWindowMaximize), keyEquivalent: "").setShortcut(for: .resizeMaximize)
        
        resizeWindow.submenu?.addItem(NSMenuItem.separator())
        
        resizeWindow.submenu?.addItem(withTitle: "Top", action: #selector(resizeWindowTopHalf), keyEquivalent: "").setShortcut(for: .resizeTopHalf)
        resizeWindow.submenu?.addItem(withTitle: "Bottom", action: #selector(resizeWindowBottomHalf), keyEquivalent: "").setShortcut(for: .resizeBottomHalf)
        resizeWindow.submenu?.addItem(withTitle: "Right", action: #selector(resizeWindowRightHalf), keyEquivalent: "").setShortcut(for: .resizeRightHalf)
        resizeWindow.submenu?.addItem(withTitle: "Left", action: #selector(resizeWindowLeftHalf), keyEquivalent: "").setShortcut(for: .resizeLeftHalf)
        
        resizeWindow.submenu?.addItem(NSMenuItem.separator())
        
        resizeWindow.submenu?.addItem(withTitle: "Top Right", action: #selector(resizeWindowTopRightQuarter), keyEquivalent: "").setShortcut(for: .resizeTopRightQuarter)
        resizeWindow.submenu?.addItem(withTitle: "Top Left", action: #selector(resizeWindowTopLeftQuarter), keyEquivalent: "").setShortcut(for: .resizeTopLeftQuarter)
        resizeWindow.submenu?.addItem(withTitle: "Bottom Right", action: #selector(resizeWindowBottomRightQuarter), keyEquivalent: "").setShortcut(for: .resizeBottomRightQuarter)
        resizeWindow.submenu?.addItem(withTitle: "Bottom Left", action: #selector(resizeWindowBottomLeftQuarter), keyEquivalent: "").setShortcut(for: .resizeBottomLeftQuarter)
        
        if let items = resizeWindow.submenu?.items {
            for item in items {
                item.target = self
            }
        }
        
        let loopMenu = NSMenu()
        loopMenu.addItem(resizeWindow)
        loopMenu.addItem(NSMenuItem.separator())
        loopMenu.addItem(withTitle: "Preferences", action: #selector(self.openSettings), keyEquivalent: ",").target = self
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
    
    @objc func openSettings() {
        if #available(macOS 13, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
