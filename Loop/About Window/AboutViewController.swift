//
//  AboutViewManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-04-08.
//

import SwiftUI

class AboutViewController {
    var aboutWindowController: NSWindowController?
    
    public func showAboutWindow() {
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
        NSApp.activate(ignoringOtherApps: true)
    }
}
