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
        
        radialMenuController.AddObservers()
        self.setKeybindings()
        
        // Show settings window on launch if this is a debug build
        #if DEBUG
        print("Debug build!")
        #endif
    }
    
    func setKeybindings() {
        KeyboardShortcuts.onKeyDown(for: .maximize) { [self] in
            windowEngine.resizeFrontmostWindow(direction: .maximize)
        }
        
        KeyboardShortcuts.onKeyDown(for: .topHalf) { [self] in
            windowEngine.resizeFrontmostWindow(direction: .topHalf)
        }
        KeyboardShortcuts.onKeyDown(for: .rightHalf) { [self] in
            windowEngine.resizeFrontmostWindow(direction: .rightHalf)
        }
        KeyboardShortcuts.onKeyDown(for: .bottomHalf) { [self] in
            windowEngine.resizeFrontmostWindow(direction: .bottomHalf)
        }
        KeyboardShortcuts.onKeyDown(for: .leftHalf) { [self] in
            windowEngine.resizeFrontmostWindow(direction: .leftHalf)
        }
        
        KeyboardShortcuts.onKeyDown(for: .topRightQuarter) { [self] in
            windowEngine.resizeFrontmostWindow(direction: .topRightQuarter)
        }
        KeyboardShortcuts.onKeyDown(for: .topLeftQuarter) { [self] in
            windowEngine.resizeFrontmostWindow(direction: .topLeftQuarter)
        }
        KeyboardShortcuts.onKeyDown(for: .bottomRightQuarter) { [self] in
            windowEngine.resizeFrontmostWindow(direction: .bottomRightQuarter)
        }
        KeyboardShortcuts.onKeyDown(for: .bottomLeftQuarter) { [self] in
            windowEngine.resizeFrontmostWindow(direction: .bottomLeftQuarter)
        }
        
        KeyboardShortcuts.onKeyDown(for: .rightThird) { [self] in
            windowEngine.resizeFrontmostWindow(direction: .rightThird)
        }
        KeyboardShortcuts.onKeyDown(for: .rightTwoThirds) { [self] in
            windowEngine.resizeFrontmostWindow(direction: .rightTwoThirds)
        }
        KeyboardShortcuts.onKeyDown(for: .horizontalCenterThird) { [self] in
            windowEngine.resizeFrontmostWindow(direction: .horizontalCenterThird)
        }
        KeyboardShortcuts.onKeyDown(for: .leftThird) { [self] in
            windowEngine.resizeFrontmostWindow(direction: .leftThird)
        }
        KeyboardShortcuts.onKeyDown(for: .leftTwoThirds) { [self] in
            windowEngine.resizeFrontmostWindow(direction: .leftTwoThirds)
        }
    }
}
