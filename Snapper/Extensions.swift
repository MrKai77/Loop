//
//  Extensions.swift
//  WindowManager
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import KeyboardShortcuts
import CoreImage.CIFilterBuiltins
import Defaults

// Add variables for keyboard shortcuts
extension KeyboardShortcuts.Name {
    static let resizeMaximize = Self("resizeMaximize", default: .init(.slash, modifiers: [.control, .option]))
    
    static let resizeTopHalf = Self("resizeTopHalf", default: .init(.upArrow, modifiers: [.control, .option]))
    static let resizeRightHalf = Self("resizeRightHalf", default: .init(.rightArrow, modifiers: [.control, .option]))
    static let resizeBottomHalf = Self("resizeBottomHalf", default: .init(.downArrow, modifiers: [.control, .option]))
    static let resizeLeftHalf = Self("resizeLeftHalf", default: .init(.leftArrow, modifiers: [.control, .option]))
    
    static let resizeTopRightQuarter = Self("resizeTopRightQuarter", default: .init(.i, modifiers: [.control, .option]))
    static let resizeTopLeftQuarter = Self("resizeTopLeftQuarter", default: .init(.u, modifiers: [.control, .option]))
    static let resizeBottomRightQuarter = Self("resizeBottomRightQuarter", default: .init(.k, modifiers: [.control, .option]))
    static let resizeBottomLeftQuarter = Self("resizeBottomLeftQuarter", default: .init(.j, modifiers: [.control, .option]))
}

// Add variables for default values (which are stored even then the app is closed)
extension Defaults.Keys {
    static let isAccessibilityAccessGranted = Key<Bool>("isAccessibilityAccessGranted", default: false)
    
    static let snapperUsesSystemAccentColor = Key<Bool>("snapperUsesSystemAccentColor", default: false)
    static let snapperAccentColor = Key<Color>("snapperAccentColor", default: Color(.white))
    static let snapperAccentColorUseGradient = Key<Bool>("snapperAccentColorUseGradient", default: false)
    static let snapperAccentColorGradient = Key<Color>("snapperAccentColorGradient", default: Color(.black))
    
    static let snapperTrigger = Key<Int>("snapperTrigger", default: 524608)
    static let snapperCornerRadius = Key<CGFloat>("snapperCornerRadius", default: 50)
    static let snapperThickness = Key<CGFloat>("snapperThickness", default: 20)
    
    static let showPreviewWhenSnapping = Key<Bool>("showPreviewWhenSnapping", default: true)
    static let snapperPreviewCornerRadius = Key<CGFloat>("snapperPreviewCornerRadius", default: 15)
    static let snapperPreviewPadding = Key<CGFloat>("snapperPreviewPadding", default: 10)
    static let snapperPreviewBorderThickness = Key<CGFloat>("snapperPreviewBorderThickness", default: 0)
}

// Add a notification name to specify then the user changes their snapping direction in the radial menu
extension Notification.Name {
    static let currentSnappingDirectionChanged = Notification.Name("currentSnappingDirectionChanged")
}

// Enum that stores all possible resizing options
enum WindowSnappingOptions: CaseIterable {
    case topHalf
    case rightHalf
    case bottomHalf
    case leftHalf
    case topRightQuarter
    case topLeftQuarter
    case bottomRightQuarter
    case bottomLeftQuarter
    case maximize
    case doNothing
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
    
    func distance(to comparisonPoint: CGPoint) -> CGFloat {
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
}
