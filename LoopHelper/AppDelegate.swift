//
//  AppDelegate.swift
//  LoopHelper
//
//  Created by Kai Azim on 2023-02-01.
//

import SwiftUI

extension Notification.Name {
    static let killHelper = Notification.Name("killHelper")
}

class AppDelegate: NSObject {
    @objc func terminate() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        let mainAppIdentifier = "com.KaiAzim.Loop"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == mainAppIdentifier }.isEmpty

        if !isRunning {
            DistributedNotificationCenter
                .default()
                .addObserver(self,
                             selector: #selector(self.terminate),
                             name: .killHelper,
                             object: mainAppIdentifier)

            if !isRunning,
               let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: mainAppIdentifier) {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
                }
            }
        } else {
            self.terminate()
        }
    }
}
