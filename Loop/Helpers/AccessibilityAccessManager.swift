//
//  AccessibilityAccessManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-04-08.
//

import SwiftUI
import Defaults

class AccessibilityAccessManager {
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
