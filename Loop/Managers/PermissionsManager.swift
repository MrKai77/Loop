//
//  AccessibilityAccessManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-04-08.
//

import SwiftUI
import Defaults

class AccessibilityManager {
    static func getStatus() -> Bool {
        // Get current state for accessibility access
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: false]
        let status = AXIsProcessTrustedWithOptions(options)

        return status
    }

    @discardableResult
    static func requestAccess() -> Bool {
        if AccessibilityManager.getStatus() {
            return true
        }
        let alert = NSAlert()
        alert.messageText = .init(
            localized: .init(
                "Accessibility Request: Title",
                defaultValue: "\(Bundle.main.appName) Needs Accessibility Permissions"
            )
        )
        alert.informativeText = .init(
            localized: .init(
                "Accessibility Request: Content",
                defaultValue: "Please grant access to be able to resize windows."
            )
        )
        alert.runModal()

        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        let status = AXIsProcessTrustedWithOptions(options)

        return status
    }
}
