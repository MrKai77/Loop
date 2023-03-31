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
        resizeWindowMenuItem(title: "Left Third", selector: #selector(resizeWindowLeftThird), shortcut: .resizeLeftThird),
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
        loopMenu.addItem(withTitle: "Settings", action: #selector(openSettings), keyEquivalent: ",").target = self
        loopMenu.addItem(withTitle: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")
        
        statusItem.menu = loopMenu
    }
    
    @objc func resizeWindowMaximize() {
        windowResizer.resizeFrontmostWindow(.maximize)
    }
    
    @objc func resizeWindowTopHalf() {
        windowResizer.resizeFrontmostWindow(.topHalf)
    }
    @objc func resizeWindowBottomHalf() {
        windowResizer.resizeFrontmostWindow(.bottomHalf)
    }
    @objc func resizeWindowRightHalf() {
        windowResizer.resizeFrontmostWindow(.rightHalf)
    }
    @objc func resizeWindowLeftHalf() {
        windowResizer.resizeFrontmostWindow(.leftHalf)
    }
    
    @objc func resizeWindowTopRightQuarter() {
        windowResizer.resizeFrontmostWindow(.topRightQuarter)
    }
    @objc func resizeWindowTopLeftQuarter() {
        windowResizer.resizeFrontmostWindow(.topLeftQuarter)
    }
    @objc func resizeWindowBottomRightQuarter() {
        windowResizer.resizeFrontmostWindow(.bottomRightQuarter)
    }
    @objc func resizeWindowBottomLeftQuarter() {
        windowResizer.resizeFrontmostWindow(.bottomLeftQuarter)
    }
    
    @objc func resizeWindowRightThird() {
        windowResizer.resizeFrontmostWindow(.rightThird)
    }
    @objc func resizeWindowRightTwoThirds() {
        windowResizer.resizeFrontmostWindow(.rightTwoThirds)
    }
    @objc func resizeWindowRLCenterThird() {
        windowResizer.resizeFrontmostWindow(.RLcenterThird)
    }
    @objc func resizeWindowLeftTwoThirds() {
        windowResizer.resizeFrontmostWindow(.leftTwoThirds)
    }
    @objc func resizeWindowLeftThird() {
        windowResizer.resizeFrontmostWindow(.leftThird)
    }
    
    @objc func openSettings() {
        if #available(macOS 13, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
