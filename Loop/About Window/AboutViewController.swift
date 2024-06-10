//
//  AboutViewController.swift
//  Loop
//
//  Created by Kai Azim on 2023-04-08.
//

import SwiftUI

class AboutViewController {
    var aboutWindowController: NSWindowController?

    func open() {
        if aboutWindowController == nil {
            let window = NSWindow()
            window.styleMask = [.closable, .titled, .fullSizeContentView]
            window.title = .init(localized: .init("About", defaultValue: "About \(Bundle.main.appName)"))
            window.contentView = NSHostingView(rootView: AboutView())
            window.titlebarAppearsTransparent = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.isMovableByWindowBackground = true
            window.center()
            aboutWindowController = .init(window: window)
        } else {
            // Refresh view, in case user changed app icon
            aboutWindowController?.window?.contentView = NSHostingView(rootView: AboutView())
        }

        aboutWindowController?.showWindow(aboutWindowController?.window)
        aboutWindowController?.window?.orderFrontRegardless()
    }
}
