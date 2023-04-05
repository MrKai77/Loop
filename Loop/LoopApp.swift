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
    let iconManager = IconManager()
    
    var aboutWindowController: NSWindowController?
    
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
        if !checkAccessibilityAccess(ask: false) {
            accessibilityAccessAlert()
        }
        
        setKeybindings()
        radialMenu.AddObservers()
        loopMenubarController.show()
        
        // Show settings window on launch if this is a debug build
        #if DEBUG
        loopMenubarController.openSettings()
        NSApp.activate(ignoringOtherApps: true)
        print("Debug build!")
        #endif
        
        iconManager.setCurrentAppIcon()
    }
    
    
    private func setKeybindings() {
        KeyboardShortcuts.onKeyDown(for: .resizeMaximize) { [self] in
            windowResizer.resizeFrontmostWindow(.maximize)
        }
        
        KeyboardShortcuts.onKeyDown(for: .resizeTopHalf) { [self] in
            windowResizer.resizeFrontmostWindow(.topHalf)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeRightHalf) { [self] in
            windowResizer.resizeFrontmostWindow(.rightHalf)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeBottomHalf) { [self] in
            windowResizer.resizeFrontmostWindow(.bottomHalf)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeLeftHalf) { [self] in
            windowResizer.resizeFrontmostWindow(.leftHalf)
        }
        
        KeyboardShortcuts.onKeyDown(for: .resizeTopRightQuarter) { [self] in
            windowResizer.resizeFrontmostWindow(.topRightQuarter)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeTopLeftQuarter) { [self] in
            windowResizer.resizeFrontmostWindow(.topLeftQuarter)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeBottomRightQuarter) { [self] in
            windowResizer.resizeFrontmostWindow(.bottomRightQuarter)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeBottomLeftQuarter) { [self] in
            windowResizer.resizeFrontmostWindow(.bottomLeftQuarter)
        }
        
        KeyboardShortcuts.onKeyDown(for: .resizeRightThird) { [self] in
            windowResizer.resizeFrontmostWindow(.rightThird)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeRightTwoThirds) { [self] in
            windowResizer.resizeFrontmostWindow(.rightTwoThirds)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeRLCenterThird) { [self] in
            windowResizer.resizeFrontmostWindow(.RLcenterThird)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeLeftThird) { [self] in
            windowResizer.resizeFrontmostWindow(.leftThird)
        }
        KeyboardShortcuts.onKeyDown(for: .resizeLeftTwoThirds) { [self] in
            windowResizer.resizeFrontmostWindow(.leftTwoThirds)
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
    func checkAccessibilityAccess(ask: Bool) -> Bool {
        // Get current state for accessibility access
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: ask]
        let status = AXIsProcessTrustedWithOptions(options)
        
        Defaults[.isAccessibilityAccessGranted] = status
        return status
    }
    
    func accessibilityAccessAlert() {
        let alert = NSAlert()
        alert.messageText = "\(Bundle.main.appName) Needs Accessibility Permissions"
        alert.informativeText = "Welcome to \(Bundle.main.appName)! Please grant accessibility access to be able to resize windows."
        alert.runModal()
        
        checkAccessibilityAccess(ask: true)
    }
}
