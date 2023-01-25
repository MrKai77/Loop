//
//  Extensions.swift
//  WindowManager
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import KeyboardShortcuts
import Defaults

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

extension Defaults.Keys {
    static let snapperTrigger = Key<Int>("snapperTrigger", default: 262401)
    static let showPreviewWhenSnapping = Key<Bool>("showPreviewWhenSnapping", default: true)
    static let isAccessibilityAccessGranted = Key<Bool>("isAccessibilityAccessGranted", default: false)
}

extension Notification.Name {
    static let currentSnappingDirectionChanged = Notification.Name("currentSnappingDirectionChanged")
    static let finishedLaunching = Notification.Name("finishedLaunching")
}

enum WindowSnappingOptions {
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

extension Angle {
    // Returns an Angle in the range 0° ..< 360°
    func normalized() -> Angle {
        let degrees = (self.degrees.truncatingRemainder(dividingBy: 360) + 360)
                      .truncatingRemainder(dividingBy: 360)

        return Angle(degrees: degrees)
    }
}

private typealias CGSConnectionID = UInt
private typealias CGSSpaceID = UInt64
@_silgen_name("CGSCopySpaces")
private func CGSCopySpaces(_: Int, _: Int) -> CFArray
@_silgen_name("CGSAddWindowsToSpaces")
private func CGSAddWindowsToSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)

extension NSWindow {    // This extension allows the window to be put on "top" of spaces, making it slide with you when you change spaces!
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

struct VerticalLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            configuration.icon
            configuration.title
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return self.deviceDescription[key] as! CGDirectDisplayID
    }
}
