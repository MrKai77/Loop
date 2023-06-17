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
        
        
        MenuBarExtra("Loop", image: "menubarIcon") {
            if #available(macOS 14, *) {
                SettingsLink()
            }
            else {
                Button("Settings") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            
            Button("About \(Bundle.main.appName)") {
                aboutViewController.showAboutWindow()
            }
            
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    let windowEngine = WindowEngine()
    let radialMenuController = RadialMenuController()
    let aboutViewController = AboutViewController()
    let iconManager = IconManager()
    let accessibilityAccessManager = AccessibilityAccessManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        do {
            try AppMover.moveApp()
        } catch {
            print("Moving app failed: \(error)")
        }
        
        // Check accessibility access, then if access is not granted, show a more informative alert asking for accessibility access
        if !accessibilityAccessManager.checkAccessibilityAccess(ask: false) {
            accessibilityAccessManager.accessibilityAccessAlert()
        }
        iconManager.setCurrentAppIcon()
        
        windowEngine.setKeybindings()
        radialMenuController.AddObservers()
        
        // Show settings window on launch if this is a debug build
        #if DEBUG
        print("Debug build!")
        #endif
    }
}
