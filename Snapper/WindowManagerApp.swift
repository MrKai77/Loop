//
//  SnapperApp.swift
//  WindowManager
//
//  Created by Kai Azim on 2023-01-23.
//

import SwiftUI

@main
struct SnapperApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("WindowManager", systemImage: "hammer.fill") {
            Text("Boo!")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var screenWidth:CGFloat = 0
    var screenHeight:CGFloat = 0
    
    let windowResizer = WindowResizer()
    let radialMenu = RadialMenu()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        checkScreenRecordingAccess()
        checkAccessibilityAccess()
        
        radialMenu.AddObservers()
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
