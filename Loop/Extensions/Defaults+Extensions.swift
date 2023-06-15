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
    static let currentIcon = Key<String>("loopCurrentIcon", default: "AppIcon-Default")
    static let timesLooped = Key<Int>("timesLooped", default: 0)
    
    static let loopLaunchAtLogin = Key<Bool>("loopLaunchAtLogin", default: false)
    static let isAccessibilityAccessGranted = Key<Bool>("isAccessibilityAccessGranted", default: false)
    
    static let loopUsesSystemAccentColor = Key<Bool>("loopUsesSystemAccentColor", default: false)
    static let loopAccentColor = Key<Color>("loopAccentColor", default: Color(.white))
    static let loopUsesAccentColorGradient = Key<Bool>("loopUsesAccentColorGradient", default: false)
    static let loopAccentColorGradient = Key<Color>("loopAccentColorGradient", default: Color(.black))
    
    static let loopRadialMenuTrigger = Key<Int>("loopTriggerKeyCode", default: 59)
    static let loopRadialMenuCornerRadius = Key<CGFloat>("loopCornerRadius", default: 50)
    static let loopRadialMenuThickness = Key<CGFloat>("loopThickness", default: 22)
    
    static let loopPreviewVisibility = Key<Bool>("loopPreviewVisibility", default: true)
    static let loopPreviewCornerRadius = Key<CGFloat>("loopPreviewCornerRadius", default: 15)
    static let loopPreviewPadding = Key<CGFloat>("loopPreviewPadding", default: 10)
    static let loopPreviewBorderThickness = Key<CGFloat>("loopPreviewBorderThickness", default: 0)
}
