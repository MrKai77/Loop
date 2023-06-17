//
//  Defaults+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import SwiftUI
import Defaults

// Add variables for default values (which are stored even then the app is closed)
extension Defaults.Keys {
    static let launchAtLogin = Key<Bool>("launchAtLogin", default: false)
    static let currentIcon = Key<String>("currentIcon", default: "AppIcon-Default")
    static let timesLooped = Key<Int>("timesLooped", default: 0)
    static let isAccessibilityAccessGranted = Key<Bool>("isAccessibilityAccessGranted", default: false)
    
    static let useSystemAccentColor = Key<Bool>("useSystemAccentColor", default: false)
    static let accentColor = Key<Color>("accentColor", default: Color(.white))
    static let useGradientAccentColor = Key<Bool>("useGradientAccentColor", default: false)
    static let gradientAccentColor = Key<Color>("gradientAccentColor", default: Color(.black))
    
    static let radialMenuTrigger = Key<Int>("radialMenuTrigger", default: 59)
    static let radialMenuCornerRadius = Key<CGFloat>("radialMenuCornerRadius", default: 50)
    static let radialMenuThickness = Key<CGFloat>("radialMenuThickness", default: 22)
    
    static let previewVisibility = Key<Bool>("previewVisibility", default: true)
    static let previewCornerRadius = Key<CGFloat>("previewCornerRadius", default: 15)
    static let previewPadding = Key<CGFloat>("previewPadding", default: 10)
    static let previewBorderThickness = Key<CGFloat>("previewBorderThickness", default: 0)
    
    static let useKeyboardShortcuts = Key<Bool>("useKeyboardShortcuts", default: false)
}
