//
//  AccessibilityAccessManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-04-08.
//

import SwiftUI
import Defaults

class PermissionsManager {
    class Accessibility {
        static func getStatus() -> Bool {
            // Get current state for accessibility access
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: false]
            let status = AXIsProcessTrustedWithOptions(options)

            return status
        }

        static func requestAccess() {
            if PermissionsManager.Accessibility.getStatus() {
                return
            }
            let alert = NSAlert()
            alert.messageText = "\(Bundle.main.appName) Needs Accessibility Permissions"
            alert.informativeText = "Please grant accessibility access to be able to resize windows."
            alert.runModal()
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
            alert.messageText = "\(Bundle.main.appName) Needs Screen Recording Permissions"
            alert.informativeText = "Please grant screen recording access to be able to resize windows (with animation)."
            alert.runModal()

            CGRequestScreenCaptureAccess()
        }
    }
}
