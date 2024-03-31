//
//  AccessibilityAccessManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-04-08.
//

import SwiftUI
import Defaults

class PermissionsManager {
    static func requestAccess() {
        PermissionsManager.Accessibility.requestAccess()
        PermissionsManager.ScreenRecording.requestAccess()
    }

    class Accessibility {
        static func getStatus() -> Bool {
            // Get current state for accessibility access
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: false]
            let status = AXIsProcessTrustedWithOptions(options)

            return status
        }

        @discardableResult
        static func requestAccess() -> Bool {
            if PermissionsManager.Accessibility.getStatus() {
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

    class ScreenRecording {
        static func getStatus() -> Bool {
            return CGPreflightScreenCaptureAccess()
        }

        static func requestAccess() {
            if PermissionsManager.ScreenRecording.getStatus() {
                return
            }

            let alert = NSAlert()
            alert.messageText = .init(
                localized: .init(
                    "Screen Recording Request: Title",
                    defaultValue: "\(Bundle.main.appName) Needs Screen Recording Permissions"
                )
            )
            alert.informativeText = .init(
                localized: .init(
                    "Screen Recording Request: Content",
                    defaultValue: """
                    Screen recording permissions are required to animate windows being resized. \(Bundle.main.appName) may need to be relaunched to reflect these changes.
                    """
                )
            )
            alert.runModal()

            CGRequestScreenCaptureAccess()
        }
    }
}
