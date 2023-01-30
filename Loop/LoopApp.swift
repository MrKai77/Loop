//
//  LoopApp.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import SwiftUI
import KeyboardShortcuts
import Defaults

@main
struct LoopApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: CommandGroupPlacement.appInfo) {
                Button("About \(Bundle.main.appName)") { appDelegate.showAboutWindow() }
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
    let radialMenu = RadialMenuController()
    let loopMenubarController = LoopMenubarController()
    
    var aboutWindowController: NSWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        self.checkAccessibilityAccess()
        self.setKeybindings()
        radialMenu.AddObservers()
        loopMenubarController.show()
        
        // Show settings window on launch if this is a debug build
        #if DEBUG
        if #available(macOS 13, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        print("Debug build!")
        #endif
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
        
        KeyboardShortcuts.onKeyDown(for: .resizeRightThird) { [self] in
            windowResizer.resizeFrontmostWindowWithDirection(.rightThird)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeRightTwoThirds) { [self] in
            windowResizer.resizeFrontmostWindowWithDirection(.rightTwoThirds)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeRLCenterThird) { [self] in
            windowResizer.resizeFrontmostWindowWithDirection(.RLcenterThird)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeLeftThird) { [self] in
            windowResizer.resizeFrontmostWindowWithDirection(.leftThird)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeLeftTwoThirds) { [self] in
            windowResizer.resizeFrontmostWindowWithDirection(.leftTwoThirds)
        }
    }
    
    func showAboutWindow() {
        if aboutWindowController == nil {
            let window = NSWindow()
            window.styleMask = [.closable, .titled, .fullSizeContentView]
            window.title = "About \(Bundle.main.appName)"
            window.contentView = NSHostingView(rootView: AboutView())
            window.titlebarAppearsTransparent = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.isMovableByWindowBackground = true
            window.center()
            aboutWindowController = .init(window: window)
        }
        
        aboutWindowController?.showWindow(aboutWindowController?.window)
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
