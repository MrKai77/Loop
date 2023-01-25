//
//  SnapperApp.swift
//  WindowManager
//
//  Created by Kai Azim on 2023-01-23.
//

import SwiftUI
import WindowManagement
import KeyboardShortcuts

@main
struct SnapperApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
                .frame(width: 450, height: 450)
        }
        .registerSettingsWindow()
        .titlebarAppearsTransparent(true)
        .windowButton(.miniaturizeButton, hidden: true)
        .windowButton(.zoomButton, hidden: true)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var screenWidth:CGFloat = 0
    var screenHeight:CGFloat = 0
    
    let windowResizer = WindowResizer()
    let radialMenu = RadialMenuController()
    let snapperMenu = SnapperMenuController()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        self.checkScreenRecordingAccess()
        self.checkAccessibilityAccess()
        self.setKeybindings()
        radialMenu.AddObservers()
        snapperMenu.show()
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
    
    func checkScreenRecordingAccess() {
        if (!CGPreflightScreenCaptureAccess()) {
            print("not granted!")
            let result = CGRequestScreenCaptureAccess()
            if(result == true) {
                print("Screen recording granted, thank you.")
            } else {
                print("Not granted! Bye-bye...")
                NSApp.terminate(nil)
            }
        }
    }
    
    func checkAccessibilityAccess() {
        //get the value for accessibility
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options = [checkOptPrompt: true]
        
        //translate into boolean value
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary?)
        
        if !accessEnabled {
            print("Prompted user for accessibility access!")
        }
        
        print("Accessibility access has been checked!")
    }
}
