//
//  WindowDirection.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import Defaults
import SwiftUI

// Enum that stores all possible resizing options
enum WindowDirection: String, CaseIterable, Identifiable, Codable {
    var id: Self { self }

    // General Actions
    case noAction = "NoAction", maximize = "Maximize", almostMaximize = "AlmostMaximize", fullscreen = "Fullscreen"
    case maximizeHeight = "MaximizeHeight", maximizeWidth = "MaximizeWidth"
    case undo = "Undo", initialFrame = "InitialFrame", hide = "Hide", minimize = "Minimize", minimizeOthers = "MinimizeOthers"
    case macOSCenter = "MacOSCenter", center = "Center"

    // Halves
    case topHalf = "TopHalf", rightHalf = "RightHalf", bottomHalf = "BottomHalf", leftHalf = "LeftHalf"
    case horizontalCenterHalf = "HorizontalCenterHalf", verticalCenterHalf = "VerticalCenterHalf"

    // Quarters
    case topLeftQuarter = "TopLeftQuarter", topRightQuarter = "TopRightQuarter"
    case bottomRightQuarter = "BottomRightQuarter", bottomLeftQuarter = "BottomLeftQuarter"

    // Horizontal Thirds
    case rightThird = "RightThird", rightTwoThirds = "RightTwoThirds"
    case horizontalCenterThird = "HorizontalCenterThird"
    case leftThird = "LeftThird", leftTwoThirds = "LeftTwoThirds"

    // Horizontal Fourths
    case firstFourth = "FirstFourth", secondFourth = "SecondFourth", thirdFourth = "ThirdFourth", fourthFourth = "FourthFourth"
    case leftThreeFourths = "LeftThreeFourths", rightThreeFourths = "RightThreeFourths"

    // Vertical Thirds
    case topThird = "TopThird", topTwoThirds = "TopTwoThirds"
    case verticalCenterThird = "VerticalCenterThird"
    case bottomThird = "BottomThird", bottomTwoThirds = "BottomTwoThirds"

    // Screen Switching
    case nextScreen = "NextScreen", previousScreen = "PreviousScreen", leftScreen = "LeftScreen", rightScreen = "RightScreen", topScreen = "TopScreen", bottomScreen = "BottomScreen"

    // Size Adjustment
    case larger = "Larger", smaller = "Smaller"

    // Shrink
    case shrinkTop = "ShrinkTop", shrinkBottom = "ShrinkBottom", shrinkRight = "ShrinkRight", shrinkLeft = "ShrinkLeft", shrinkHorizontal = "ShrinkHorizontal", shrinkVertical = "ShrinkVertical"

    // Grow
    case growTop = "GrowTop", growBottom = "GrowBottom", growRight = "GrowRight", growLeft = "GrowLeft", growHorizontal = "GrowHorizontal", growVertical = "GrowVertical"

    // Move
    case moveUp = "MoveUp", moveDown = "MoveDown", moveRight = "MoveRight", moveLeft = "MoveLeft"

    // Stash
    case stash = "Stash"
    case unstash = "Unstash"

    // Custom Actions
    case custom = "Custom", cycle = "Cycle"

    // These are used in the menubar resize submenu & keybind configuration
    static var general: [WindowDirection] { [.fullscreen, .maximize, .almostMaximize, .maximizeHeight, .maximizeWidth, .center, .macOSCenter, .minimize, .minimizeOthers, .hide] }
    static var halves: [WindowDirection] { [.topHalf, .verticalCenterHalf, .bottomHalf, .leftHalf, .horizontalCenterHalf, .rightHalf] }
    static var quarters: [WindowDirection] { [.topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter] }
    static var horizontalThirds: [WindowDirection] { [.rightThird, .rightTwoThirds, .horizontalCenterThird, .leftTwoThirds, .leftThird] }
    static var verticalThirds: [WindowDirection] { [.topThird, .topTwoThirds, .verticalCenterThird, .bottomTwoThirds, .bottomThird] }
    static var horizontalFourths: [WindowDirection] { [.firstFourth, .secondFourth, .thirdFourth, .fourthFourth, .leftThreeFourths, .rightThreeFourths] }
    static var screenSwitching: [WindowDirection] { [.nextScreen, .previousScreen, .leftScreen, .rightScreen, .topScreen, .bottomScreen] }
    static var sizeAdjustment: [WindowDirection] { [.larger, .smaller] }
    static var shrink: [WindowDirection] { [.shrinkTop, .shrinkBottom, .shrinkRight, .shrinkLeft, .shrinkHorizontal, .shrinkVertical] }
    static var grow: [WindowDirection] { [.growTop, .growBottom, .growRight, .growLeft, .growHorizontal, .growVertical] }
    static var move: [WindowDirection] { [.moveUp, .moveDown, .moveRight, .moveLeft] }
    static var more: [WindowDirection] { [.initialFrame, .undo, .custom, .cycle] }

    // Computed properties for checking conditions
    var willChangeScreen: Bool { WindowDirection.screenSwitching.contains(self) }
    var willAdjustSize: Bool { WindowDirection.sizeAdjustment.contains(self) }
    var willShrink: Bool { WindowDirection.shrink.contains(self) }
    var willGrow: Bool { WindowDirection.grow.contains(self) }
    var willMove: Bool { WindowDirection.move.contains(self) }
    var willMaximize: Bool { [.fullscreen, .maximize, .almostMaximize, .maximizeHeight, .maximizeWidth].contains(self) }
    var willCenter: Bool { [.center, .macOSCenter, .verticalCenterHalf, .horizontalCenterHalf].contains(self) }
    var isCustomizable: Bool { [.custom, .stash].contains(self) }

    var hasRadialMenuAngle: Bool {
        let noAngleActions: [WindowDirection] = [.noAction, .minimize, .minimizeOthers, .hide, .initialFrame, .undo, .cycle]
        return !(noAngleActions.contains(self) || willChangeScreen || willAdjustSize || willShrink || willGrow || willMove || willMaximize || willCenter)
    }

    var shouldFillRadialMenu: Bool { willMaximize || willCenter }

    var frameMultiplyValues: CGRect? {
        switch self {
        case .maximize: .init(x: 0, y: 0, width: 1.0, height: 1.0)
        case .almostMaximize: .init(x: 0.5 / 10.0, y: 0.5 / 10.0, width: 9.0 / 10.0, height: 9.0 / 10.0)
        case .fullscreen: .init(x: 0, y: 0, width: 1.0, height: 1.0)
        // Halves
        case .topHalf: .init(x: 0, y: 0, width: 1.0, height: 1.0 / 2.0)
        case .rightHalf: .init(x: 1.0 / 2.0, y: 0, width: 1.0 / 2.0, height: 1.0)
        case .bottomHalf: .init(x: 0, y: 1.0 / 2.0, width: 1.0, height: 1.0 / 2.0)
        case .leftHalf: .init(x: 0, y: 0, width: 1.0 / 2.0, height: 1.0)
        case .horizontalCenterHalf: .init(x: 1.0 / 4.0, y: 0, width: 1.0 / 2.0, height: 1.0)
        case .verticalCenterHalf: .init(x: 0, y: 1.0 / 4.0, width: 1.0, height: 1.0 / 2.0)
        // Quarters
        case .topLeftQuarter: .init(x: 0, y: 0, width: 1.0 / 2.0, height: 1.0 / 2.0)
        case .topRightQuarter: .init(x: 1.0 / 2.0, y: 0, width: 1.0 / 2.0, height: 1.0 / 2.0)
        case .bottomRightQuarter: .init(x: 1.0 / 2.0, y: 1.0 / 2.0, width: 1.0 / 2.0, height: 1.0 / 2.0)
        case .bottomLeftQuarter: .init(x: 0, y: 1.0 / 2.0, width: 1.0 / 2.0, height: 1.0 / 2.0)
        // Thirds (Horizontal)
        case .rightThird: .init(x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1.0)
        case .rightTwoThirds: .init(x: 1.0 / 3.0, y: 0, width: 2.0 / 3.0, height: 1.0)
        case .horizontalCenterThird: .init(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1.0)
        case .leftThird: .init(x: 0, y: 0, width: 1.0 / 3.0, height: 1.0)
        case .leftTwoThirds: .init(x: 0, y: 0, width: 2.0 / 3.0, height: 1.0)
        // Thirds (Vertical)
        case .topThird: .init(x: 0, y: 0, width: 1.0, height: 1.0 / 3.0)
        case .topTwoThirds: .init(x: 0, y: 0, width: 1.0, height: 2.0 / 3.0)
        case .verticalCenterThird: .init(x: 0, y: 1.0 / 3.0, width: 1.0, height: 1.0 / 3.0)
        case .bottomThird: .init(x: 0, y: 2.0 / 3.0, width: 1.0, height: 1.0 / 3.0)
        case .bottomTwoThirds: .init(x: 0, y: 1.0 / 3.0, width: 1.0, height: 2.0 / 3.0)
        // Fourths (Horizontal)
        case .firstFourth: .init(x: 0, y: 0, width: 1.0 / 4.0, height: 1.0)
        case .secondFourth: .init(x: 1.0 / 4.0, y: 0, width: 1.0 / 4.0, height: 1.0)
        case .thirdFourth: .init(x: 2.0 / 4.0, y: 0, width: 1.0 / 4.0, height: 1.0)
        case .fourthFourth: .init(x: 3.0 / 4.0, y: 0, width: 1.0 / 4.0, height: 1.0)
        case .leftThreeFourths: .init(x: 0, y: 0, width: 3.0 / 4.0, height: 1.0)
        case .rightThreeFourths: .init(x: 1.0 / 4.0, y: 0, width: 3.0 / 4.0, height: 1.0)
        default: nil
        }
    }

    var nextPreviewDirection: WindowDirection {
        switch self {
        case .topHalf: .topRightQuarter
        case .topRightQuarter: .rightHalf
        case .rightHalf: .bottomRightQuarter
        case .bottomRightQuarter: .bottomHalf
        case .bottomHalf: .bottomLeftQuarter
        case .bottomLeftQuarter: .leftHalf
        case .leftHalf: .topLeftQuarter
        case .topLeftQuarter: .maximize
        default: .topHalf
        }
    }
}

extension WindowDirection: CustomDebugStringConvertible {
    var debugDescription: String {
        rawValue
    }
}
