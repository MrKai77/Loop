//
//  WindowDirection.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import SwiftUI
import Defaults

// Enum that stores all possible resizing options
// swiftlint:disable:next type_body_length
enum WindowDirection: String, CaseIterable, Identifiable, Codable {
    var id: Self { self }

    // General
    case noAction = "NoAction"
    case maximize = "Maximize"
    case almostMaximize = "AlmostMaximize"
    case fullscreen = "Fullscreen"
    case undo = "Undo"
    case center = "Center"
    case macOSCenter = "MacOSCenter"
    case initialFrame = "InitialFrame"
    case hide = "Hide"
    case minimize = "Minimize"

    // To cycle through directions
    case cycleTop = "CycleTop"
    case cycleBottom = "CycleBottom"
    case cycleRight = "CycleRight"
    case cycleLeft = "CycleLeft"

    // Halves
    case topHalf = "TopHalf"
    case rightHalf = "RightHalf"
    case bottomHalf = "BottomHalf"
    case leftHalf = "LeftHalf"

    // Quarters
    case topLeftQuarter = "TopLeftQuarter"
    case topRightQuarter = "TopRightQuarter"
    case bottomRightQuarter = "BottomRightQuarter"
    case bottomLeftQuarter = "BottomLeftQuarter"

    // Horizontal Thirds
    case rightThird = "RightThird"
    case rightTwoThirds = "RightTwoThirds"
    case horizontalCenterThird = "HorizontalCenterThird"
    case leftThird = "LeftThird"
    case leftTwoThirds = "LeftTwoThirds"

    // Vertical Thirds
    case topThird = "TopThird"
    case topTwoThirds = "TopTwoThirds"
    case verticalCenterThird = "VerticalCenterThird"
    case bottomThird = "BottomThird"
    case bottomTwoThirds = "BottomTwoThirds"

    // Screens
    case nextScreen = "NextScreen"
    case previousScreen = "PreviousScreen"

    case larger = "Larger"
    case smaller = "Smaller"

    case custom = "Custom"
    case cycle = "Cycle"

    // These are used in the menubar resize submenu & keybind configuration
    static var general: [WindowDirection] {
        [.fullscreen, .maximize, .almostMaximize, .center, .macOSCenter, .minimize, .hide]
    }
    static var halves: [WindowDirection] {
        [.topHalf, .bottomHalf, .leftHalf, .rightHalf]
    }
    static var quarters: [WindowDirection] {
        [.topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter]
    }
    static var horizontalThirds: [WindowDirection] {
        [.rightThird, .rightTwoThirds, .horizontalCenterThird, .leftTwoThirds, .leftThird]
    }
    static var verticalThirds: [WindowDirection] {
        [.topThird, .topTwoThirds, .verticalCenterThird, .bottomTwoThirds, .bottomThird]
    }
    static var cyclable: [WindowDirection] {
        [.cycleTop, .cycleBottom, .cycleLeft, .cycleRight]
    }
    static var screenSwitching: [WindowDirection] {
        [.nextScreen, .previousScreen]
    }
    static var sizeAdjustment: [WindowDirection] {
        [.larger, .smaller]
    }
    static var more: [WindowDirection] {
        [.initialFrame, .undo, .custom, .cycle]
    }

    var isPresetCyclable: Bool {
        WindowDirection.cyclable.contains(self)
    }

    var willChangeScreen: Bool {
        WindowDirection.screenSwitching.contains(self)
    }

    // Used in the settings window to loop over the possible combinations
    var nextPreviewDirection: WindowDirection {
        switch self {
        case .noAction:             .cycleTop
        case .cycleTop:             .topRightQuarter
        case .topRightQuarter:      .cycleRight
        case .cycleRight:           .bottomRightQuarter
        case .bottomRightQuarter:   .cycleBottom
        case .cycleBottom:          .bottomLeftQuarter
        case .bottomLeftQuarter:    .cycleLeft
        case .cycleLeft:            .topLeftQuarter
        case .topLeftQuarter:       .maximize
        case .maximize:             .noAction
        default:                    .noAction
        }
    }

    var radialMenuAngle: Double? {
        switch self {
        case .cycleTop:             0
        case .topRightQuarter:      45
        case .cycleRight:           90
        case .bottomRightQuarter:   135
        case .cycleBottom:          180
        case .bottomLeftQuarter:    225
        case .cycleLeft:            270
        case .topLeftQuarter:       315
        case .maximize:             0
        default:                    nil
        }
    }

    var name: String {
        var result = ""
        for (idx, char) in self.rawValue.enumerated() {
            if idx > 0,
               char.isUppercase,
               let next = self.rawValue.index(
                self.rawValue.startIndex,
                offsetBy: idx + 1,
                limitedBy: self.rawValue.endIndex
               ) {
                if self.rawValue[next].isLowercase {
                    result.append(" ")
                }
            }
            result.append(char)
        }

        return result
    }

    var moreInformation: String? {
        var result: String?

        if self.isPresetCyclable {
            result = """
            This keybind cycles: press it repeatedly to cycle through
            1/2, 1/3, and 2/3, then move onto the next screen.
            """
        }

        if self == .macOSCenter {
            result = """
            \(self.name) places windows slightly above the absolute center,
            which can be found more ergnonomic.
            """
        }

        return result
    }

    var icon: Image? {
        switch self {
        case .maximize:                 Image(systemName: "rectangle.inset.filled")
        case .almostMaximize:           Image(systemName: "rectangle.center.inset.filled")
        case .fullscreen:               Image(systemName: "rectangle.fill")
        case .center:                   Image("custom.rectangle.center.inset.inset.filled")
        case .macOSCenter:              Image("custom.rectangle.center.inset.inset.filled")
        case .undo:                     Image("custom.backward.fill.rectangle.fill")
        case .initialFrame:             Image("custom.backward.end.alt.fill.rectangle.fill")
        case .hide:                     Image("custom.rectangle.slash")
        case .minimize:                 Image(systemName: "dock.arrow.down.rectangle")

        case .cycleTop:                 Image(systemName: "rectangle.tophalf.inset.filled")
        case .cycleBottom:              Image(systemName: "rectangle.bottomhalf.inset.filled")
        case .cycleRight:               Image(systemName: "rectangle.righthalf.inset.filled")
        case .cycleLeft:                Image(systemName: "rectangle.lefthalf.inset.filled")

        case .topHalf:                  Image(systemName: "rectangle.tophalf.inset.filled")
        case .rightHalf:                Image(systemName: "rectangle.righthalf.inset.filled")
        case .bottomHalf:               Image(systemName: "rectangle.bottomhalf.inset.filled")
        case .leftHalf:                 Image(systemName: "rectangle.lefthalf.inset.filled")

        case .topLeftQuarter:           Image(systemName: "rectangle.inset.topleft.filled")
        case .topRightQuarter:          Image(systemName: "rectangle.inset.topright.filled")
        case .bottomRightQuarter:       Image(systemName: "rectangle.inset.bottomright.filled")
        case .bottomLeftQuarter:        Image(systemName: "rectangle.inset.bottomleft.filled")

        case .rightThird:               Image(systemName: "rectangle.rightthird.inset.filled")
        case .rightTwoThirds:           Image("custom.rectangle.righttwothirds.inset.filled")
        case .horizontalCenterThird:    Image("custom.rectangle.horizontalcenterthird.inset.filled")
        case .leftThird:                Image(systemName: "rectangle.leftthird.inset.filled")
        case .leftTwoThirds:            Image("custom.rectangle.lefttwothirds.inset.filled")

        case .topThird:                 Image(systemName: "rectangle.topthird.inset.filled")
        case .topTwoThirds:             Image("custom.rectangle.toptwothirds.inset.filled")
        case .verticalCenterThird:      Image("custom.rectangle.verticalcenterthird.inset.filled")
        case .bottomThird:              Image(systemName: "rectangle.bottomthird.inset.filled")
        case .bottomTwoThirds:          Image("custom.rectangle.bottomtwothirds.inset.filled")

        case .nextScreen:               Image("custom.arrow.forward.rectangle")
        case .previousScreen:           Image("custom.arrow.backward.rectangle")

        case .larger:                   Image("custom.arrow.up.left.and.arrow.down.right.rectangle")
        case .smaller:                  Image("custom.arrow.down.right.and.arrow.up.left.rectangle")

        case .custom:                   Image(systemName: "rectangle.dashed")
        case .cycle:                    Image("custom.arrow.2.squarepath.rectangle")
        default:                        nil
        }
    }

    var radialMenuImage: Image? {
        switch self {
        case .hide:                     Image("custom.rectangle.slash")
        case .minimize:                 Image("custom.arrow.down.right.and.arrow.up.left.rectangle")
        default:                        nil
        }
    }

    static func processSnap(
        mouseLocation: CGPoint,
        currentDirection: WindowDirection,
        screenFrame: CGRect,
        ignoredFrame: CGRect
    ) -> WindowDirection {
        var newDirection: WindowDirection = .noAction

        if mouseLocation.x < ignoredFrame.minX {
            newDirection = WindowDirection.processLeftSnap(mouseLocation, screenFrame)
        } else if mouseLocation.x > ignoredFrame.maxX {
            newDirection = WindowDirection.processRightSnap(mouseLocation, screenFrame)
        } else if mouseLocation.y < ignoredFrame.minY {
            newDirection = WindowDirection.processTopSnap(mouseLocation, screenFrame)
        } else if mouseLocation.y > ignoredFrame.maxY {
            newDirection = WindowDirection.processBottomSnap(mouseLocation, screenFrame, currentDirection)
        }

        return newDirection
    }

    static func processLeftSnap(
        _ mouseLocation: CGPoint,
        _ screenFrame: CGRect
    ) -> WindowDirection {
        let mouseY = mouseLocation.y
        let maxY = screenFrame.maxY
        let height = screenFrame.height

        if mouseY < maxY - (height  * 7/8) {
            return .topLeftQuarter
        } else if mouseY > maxY - (height  * 1/8) {
            return .bottomLeftQuarter
        } else {
            return .leftHalf
        }
    }

    static func processRightSnap(
        _ mouseLocation: CGPoint,
        _ screenFrame: CGRect
    ) -> WindowDirection {
        let mouseY = mouseLocation.y
        let maxY = screenFrame.maxY
        let height = screenFrame.height

        if mouseY < maxY - (height  * 7/8) {
            return .topRightQuarter
        } else if mouseY > maxY - (height  * 1/8) {
            return .bottomRightQuarter
        } else {
            return .rightHalf
        }
    }

    static func processTopSnap(
        _ mouseLocation: CGPoint,
        _ screenFrame: CGRect
    ) -> WindowDirection {
        let mouseX = mouseLocation.x
        let maxX = screenFrame.maxX
        let width = screenFrame.width

        if mouseX < maxX - (width * 4/5) || mouseX > maxX - (width * 1/5) {
            return .topHalf
        } else {
            return .maximize
        }
    }

    static func processBottomSnap(
        _ mouseLocation: CGPoint,
        _ screenFrame: CGRect,
        _ currentDirection: WindowDirection
    ) -> WindowDirection {
        var newDirection: WindowDirection

        let mouseX = mouseLocation.x
        let maxX = screenFrame.maxX
        let width = screenFrame.width

        if mouseX < maxX - (width * 2/3) {
            newDirection = .leftThird
        } else if mouseX > maxX - (width * 1/3) {
            newDirection = .rightThird
        } else {
            // mouse is within 1/3 and 2/3 of the screen's width
            newDirection = .bottomHalf

            if currentDirection == .leftThird || currentDirection == .leftTwoThirds {
                newDirection = .leftTwoThirds
            } else if currentDirection == .rightThird || currentDirection == .rightTwoThirds {
                newDirection = .rightTwoThirds
            }
        }

        return newDirection
    }

    var frameMultiplyValues: CGRect? {
        switch self {
        case .noAction:                 CGRect(x: 1.0/2.0, y: 1.0/2.0, width: 0.0, height: 0.0)
        case .maximize:                 CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
        case .almostMaximize:           CGRect(x: 0.5/10.0, y: 0.5/10.0, width: 9.0/10.0, height: 9.0/10.0)
        case .fullscreen:               CGRect(x: 0, y: 0, width: 1.0, height: 1.0)

        // Halves
        case .topHalf:                  CGRect(x: 0, y: 0, width: 1.0, height: 1.0/2.0)
        case .rightHalf:                CGRect(x: 1.0/2.0, y: 0, width: 1.0/2.0, height: 1.0)
        case .bottomHalf:               CGRect(x: 0, y: 1.0/2.0, width: 1.0, height: 1.0/2.0)
        case .leftHalf:                 CGRect(x: 0, y: 0, width: 1.0/2.0, height: 1.0)

        // Quarters
        case .topLeftQuarter:           CGRect(x: 0, y: 0, width: 1.0/2.0, height: 1.0/2.0)
        case .topRightQuarter:          CGRect(x: 1.0/2.0, y: 0, width: 1.0/2.0, height: 1.0/2.0)
        case .bottomRightQuarter:       CGRect(x: 1.0/2.0, y: 1.0/2.0, width: 1.0/2.0, height: 1.0/2.0)
        case .bottomLeftQuarter:        CGRect(x: 0, y: 1.0/2.0, width: 1.0/2.0, height: 1.0/2.0)

        // Thirds (Horizontal)
        case .rightThird:               CGRect(x: 2.0/3.0, y: 0, width: 1.0/3.0, height: 1.0)
        case .rightTwoThirds:           CGRect(x: 1.0/3.0, y: 0, width: 2.0/3.0, height: 1.0)
        case .horizontalCenterThird:    CGRect(x: 1.0/3.0, y: 0, width: 1.0/3.0, height: 1.0)
        case .leftThird:                CGRect(x: 0, y: 0, width: 1.0/3.0, height: 1.0)
        case .leftTwoThirds:            CGRect(x: 0, y: 0, width: 2.0/3.0, height: 1.0)

        // Thirds (Vertical)
        case .topThird:                 CGRect(x: 0, y: 0, width: 1.0, height: 1.0/3.0)
        case .topTwoThirds:             CGRect(x: 0, y: 0, width: 1.0, height: 2.0/3.0)
        case .verticalCenterThird:      CGRect(x: 0, y: 1.0/3.0, width: 1.0, height: 1.0/3.0)
        case .bottomThird:              CGRect(x: 0, y: 2.0/3.0, width: 1.0, height: 1.0/3.0)
        case .bottomTwoThirds:          CGRect(x: 0, y: 1.0/3.0, width: 1.0, height: 2.0/3.0)
        default:                        nil
        }
    }

    func nextCyclingDirection(from: WindowDirection) -> WindowDirection {
        switch self {
        case .cycleTop:
            switch from {
            case .topHalf:              return .topThird
            case .topThird:             return .topTwoThirds
            default:                    return .topHalf
            }
        case .cycleBottom:
            switch from {
            case .bottomHalf:           return .bottomThird
            case .bottomThird:          return .bottomTwoThirds
            default:                    return .bottomHalf
            }
        case .cycleLeft:
            switch from {
            case .leftHalf:             return .leftThird
            case .leftThird:            return .leftTwoThirds
            case .leftTwoThirds:        return .previousScreen
            case .previousScreen:       return .rightHalf
            default:                    return .leftHalf
            }
        case .cycleRight:
            switch from {
            case .rightHalf:            return .rightThird
            case .rightThird:           return .rightTwoThirds
            case .rightTwoThirds:       return .nextScreen
            case .nextScreen:           return .leftHalf
            default:                    return .rightHalf
            }
        default: return .noAction
        }
    }

    // Gets the cyclable direction
    var base: WindowDirection {
        switch self {
        case .topHalf, .topThird, .topTwoThirds: .cycleTop
        case .bottomHalf, .bottomThird, .bottomTwoThirds: .cycleBottom
        case .leftHalf, .leftThird, .leftTwoThirds: .cycleLeft
        case .rightHalf, .rightThird, .rightTwoThirds: .cycleRight
        default: self
        }
    }
}
