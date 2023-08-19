//
//  StatusItemController.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-18.
//

import SwiftUI
import WindowManagement

class StatusItemController {
    private let aboutViewController = AboutViewController()
    private var statusItem: NSStatusItem!

    func show() {
        statusItem = NSStatusBar.system.statusItem(withLength: 22)
        guard let button = statusItem.button else { return }

        let view = NSHostingView(rootView: StatusItemView())
        view.frame.size = NSSize(width: 22, height: 22)

        button.addSubview(view)

        let loopMenu = NSMenu()
        #if DEBUG
        loopMenu.addItem(withTitle: "DEBUG BUILD: \(Bundle.main.appVersion) (\(Bundle.main.appBuild))", action: nil, keyEquivalent: "")
        #endif
        loopMenu.addItem(withTitle: "Settings", action: #selector(self.openSettingsWindow), keyEquivalent: ",").target = self
        loopMenu.addItem(withTitle: "About Loop", action: #selector(self.openAboutWindow), keyEquivalent: "i").target = self
        loopMenu.addItem(NSMenuItem.separator())
        loopMenu.addItem(withTitle: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = loopMenu
    }

    @objc func openSettingsWindow() {
        NSApp.openSettings()
        NSApp.setActivationPolicy(.regular)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        for window in NSApp.windows where window.title != "About \(Bundle.main.appName)" {
            window.orderFrontRegardless()
        }
    }

    @objc func openAboutWindow() {
        self.aboutViewController.showAboutWindow()
        NSApp.setActivationPolicy(.regular)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        for window in NSApp.windows where window.title == "About \(Bundle.main.appName)" {
            window.orderFrontRegardless()
        }
    }
}

struct StatusItemView: View {
    @State var rotationAngle: Double = 0.0
    var body: some View {
        Image(.menubarIcon)
            .rotationEffect(Angle.degrees(self.rotationAngle))
            .onReceive(.finishedLooping) { _ in
                self.rotationAngle = 0
                withAnimation(.interpolatingSpring(stiffness: 100, damping: 15)) {
                    self.rotationAngle += 360
                }
            }
    }
}
