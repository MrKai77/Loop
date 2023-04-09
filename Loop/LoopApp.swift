//
//  LoopApp.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import SwiftUI
import KeyboardShortcuts
import Defaults
import ServiceManagement
import AppMover

@main
struct LoopApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let aboutViewController = AboutViewController()
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: CommandGroupPlacement.appInfo) {
                Button("About \(Bundle.main.appName)") { aboutViewController.showAboutWindow() }
                    .keyboardShortcut("i")
            }
            CommandGroup(replacing: CommandGroupPlacement.appTermination) {
                Button("Quit \(Bundle.main.appName)") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var screenWidth:CGFloat = 0
    var screenHeight:CGFloat = 0
    
    let windowResizer = WindowResizer()
    let radialMenuController = RadialMenuController()
    let aboutViewController = AboutViewController()
    let loopMenubarController = LoopMenubarController()
    let iconManager = IconManager()
    let accessibilityAccessManager = AccessibilityAccessManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        do {
            try AppMover.moveApp()
        } catch {
            print("Moving app failed: \(error)")
        }

        // If launched at login, kill login launch helper
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == LoopHelper.helperBundleID }.isEmpty
        if isRunning {
            DistributedNotificationCenter.default().post(name: .killHelper, object: Bundle.main.bundleID)
        }
        
        // Check accessibility access, then if access is not granted, show a more informative alert asking for accessibility access
        if !accessibilityAccessManager.checkAccessibilityAccess(ask: false) {
            accessibilityAccessManager.accessibilityAccessAlert()
        }
        
        windowResizer.setKeybindings()
        radialMenuController.AddObservers()
        loopMenubarController.show()
        
        // Show settings window on launch if this is a debug build
        #if DEBUG
        loopMenubarController.openSettings()
        NSApp.activate(ignoringOtherApps: true)
        print("Debug build!")
        #endif
        
        iconManager.setCurrentAppIcon()
    }
}
