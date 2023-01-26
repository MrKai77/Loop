//
//  SnapperApp.swift
//  WindowManager
//
//  Created by Kai Azim on 2023-01-23.
//

import SwiftUI
import KeyboardShortcuts
import Defaults

@main
struct SnapperApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var screenWidth:CGFloat = 0
    var screenHeight:CGFloat = 0
    
    let windowResizer = WindowResizer()
    let radialMenu = RadialMenuController()
    let snapperMenu = SnapperMenuController()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        self.checkAccessibilityAccess()
        self.setKeybindings()
        radialMenu.AddObservers()
        snapperMenu.show()
        
        if #available(macOS 13, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
    
    
    func setKeybindings() {
        KeyboardShortcuts.onKeyDown(for: .resizeMaximize) { [self] in
            windowResizer.resizeFrontmostWindowWithDirection(.maximize)
        }
        
        KeyboardShortcuts.onKeyDown(for: .resizeTopHalf) { [self] in
            windowResizer.resizeFrontmostWindowWithDirection(.topHalf)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeRightHalf) { [self] in
            windowResizer.resizeFrontmostWindowWithDirection(.rightHalf)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeBottomHalf) { [self] in
            windowResizer.resizeFrontmostWindowWithDirection(.bottomHalf)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeLeftHalf) { [self] in
            windowResizer.resizeFrontmostWindowWithDirection(.leftHalf)
        }
        
        KeyboardShortcuts.onKeyDown(for: .resizeTopRightQuarter) { [self] in
            windowResizer.resizeFrontmostWindowWithDirection(.topRightQuarter)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeTopLeftQuarter) { [self] in
            windowResizer.resizeFrontmostWindowWithDirection(.topLeftQuarter)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeBottomRightQuarter) { [self] in
            windowResizer.resizeFrontmostWindowWithDirection(.bottomRightQuarter)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeBottomLeftQuarter) { [self] in
            windowResizer.resizeFrontmostWindowWithDirection(.bottomLeftQuarter)
        }
    }
    
    @discardableResult
    func checkAccessibilityAccess() -> Bool {
        // Get current state for accessibility access
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        let status = AXIsProcessTrustedWithOptions(options)
        
        Defaults[.isAccessibilityAccessGranted] = status
        return status
    }
}
