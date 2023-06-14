//
//  Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import KeyboardShortcuts
import Defaults

// Add variables for keyboard shortcuts
extension KeyboardShortcuts.Name {
    static let maximize = Self("resizeMaximize", default: .init(.slash, modifiers: [.control, .option]))
    
    static let topHalf = Self("topHalf", default: .init(.upArrow, modifiers: [.control, .option]))
    static let rightHalf = Self("rightHalf", default: .init(.rightArrow, modifiers: [.control, .option]))
    static let bottomHalf = Self("bottomHalf", default: .init(.downArrow, modifiers: [.control, .option]))
    static let leftHalf = Self("leftHalf", default: .init(.leftArrow, modifiers: [.control, .option]))
    
    static let topRightQuarter = Self("topRightQuarter", default: .init(.i, modifiers: [.control, .option]))
    static let topLeftQuarter = Self("topLeftQuarter", default: .init(.u, modifiers: [.control, .option]))
    static let bottomRightQuarter = Self("bottomRightQuarter", default: .init(.k, modifiers: [.control, .option]))
    static let bottomLeftQuarter = Self("bottomLeftQuarter", default: .init(.j, modifiers: [.control, .option]))
    
    static let rightThird = Self("rightThird", default: .init(.d, modifiers: [.control, .option]))
    static let rightTwoThirds = Self("rightTwoThirds", default: .init(.e, modifiers: [.control, .option]))
    static let horizontalCenterThird = Self("HorizontalCenterThird", default: .init(.s, modifiers: [.control, .option]))
    static let leftThird = Self("leftThird", default: .init(.a, modifiers: [.control, .option]))
    static let leftTwoThirds = Self("leftTwoThirds", default: .init(.q, modifiers: [.control, .option]))
}

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

// Add a notification name to specify then the user changes their resizing direction in the radial menu
extension Notification.Name {
    static let currentResizingDirectionChanged = Notification.Name("currentResizingDirectionChanged")
    static let killHelper = Notification.Name("killHelper")
}

// Launch at login
struct LoopHelper {
    static let helperBundleID = "com.KaiAzim.Loop.LoopHelper"
}

// Enum that stores all possible resizing options
enum WindowResizingOptions: CaseIterable {
    
    case topHalf
    case topRightQuarter
    case rightHalf
    case bottomRightQuarter
    case bottomHalf
    case bottomLeftQuarter
    case leftHalf
    case topLeftQuarter
    case maximize
    case noAction
    
    // The following aren't accessible from the radial menu
    case rightThird
    case rightTwoThirds
    case horizontalCenterThird
    case leftThird
    case leftTwoThirds
    
    case topThird
    case topTwoThirds
    case verticalCenterThird
    case bottomThird
    case bottomTwoThirds
}

extension CaseIterable where Self: Equatable {
    func next() -> Self {
        let all = Self.allCases
        let idx = all.firstIndex(of: self)!
        let next = all.index(after: idx)
        return all[next == all.endIndex ? all.startIndex : next]
    }
}

// SwiftUI view for NSVisualEffect
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = NSVisualEffectView.State.active
        visualEffectView.isEmphasized = true
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

// Make it easier to recieve notifications SwiftUI views
extension View {
    func onReceive(
        _ name: Notification.Name,
        center: NotificationCenter = .default,
        object: AnyObject? = nil,
        perform action: @escaping (Notification) -> Void
    ) -> some View {
        onReceive(
            center.publisher(for: name, object: object),
            perform: action
        )
    }
}

// Add two extensions: one to detect the angle between two CGPoints and one to detect the distance
extension CGPoint {
    func angle(to comparisonPoint: CGPoint) -> CGFloat {
        let originX = comparisonPoint.x - x
        let originY = comparisonPoint.y - y
        let bearingRadians = -atan2f(Float(originY), Float(originX))

        return CGFloat(bearingRadians)
    }
    
    func distanceSquared(to comparisonPoint: CGPoint) -> CGFloat {
        let from = CGPoint(x: x, y: y)
        let to = comparisonPoint
        
        return (from.x - to.x) * (from.x - to.x) + (from.y - to.y) * (from.y - to.y)
    }
}

// Returns an Angle in the range 0° ..< 360°
extension Angle {
    func normalized() -> Angle {
        let degrees = (self.degrees.truncatingRemainder(dividingBy: 360) + 360)
                      .truncatingRemainder(dividingBy: 360)

        return Angle(degrees: degrees)
    }
}

// Define some types for the next function (which uses Apple's private APIs)
private typealias CGSConnectionID = UInt
private typealias CGSSpaceID = UInt64
@_silgen_name("CGSCopySpaces")
private func CGSCopySpaces(_: Int, _: Int) -> CFArray
@_silgen_name("CGSAddWindowsToSpaces")
private func CGSAddWindowsToSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)

// This extension allows the window to be put on "top" of spaces, making it slide with you when you change spaces!
extension NSWindow {
    func makeKeyAndOrderInFrontOfSpaces() {
        self.orderFrontRegardless()
        let contextID = NSApp.value(forKey: "contextID") as! Int
        let spaces: CFArray
        if #available(macOS 12.2, *) {
            spaces = CGSCopySpaces(contextID, 11)
        } else {
            spaces = CGSCopySpaces(contextID, 13)
        }
        // macOS 12.1 -> 13
        // macOS 12.2 beta 2 -> 9 or 11
        
        let windows = [NSNumber(value: windowNumber)]
        
        CGSAddWindowsToSpaces(CGSConnectionID(contextID), windows as CFArray, spaces)
    }
}

// Return the CGDirectDisplayID (used in WindowResizer.swift)
extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return self.deviceDescription[key] as! CGDirectDisplayID
    }
    
    func screenWithMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) })

        return screenWithMouse
    }
}

// Returns the current build number
extension Bundle {
    public var appName: String { getInfo("CFBundleName")  }
    public var displayName: String { getInfo("CFBundleDisplayName") }
    public var bundleID: String { getInfo("CFBundleIdentifier") }
    public var copyright: String { getInfo("NSHumanReadableCopyright") }
    
    public var appBuild: String { getInfo("CFBundleVersion") }
    public var appVersion: String { getInfo("CFBundleShortVersionString") }
    
    fileprivate func getInfo(_ str: String) -> String { infoDictionary?[str] as? String ?? "⚠️" }
}
