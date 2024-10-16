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
    case noAction = "NoAction", maximize = "Maximize", almostMaximize = "AlmostMaximize", fullscreen = "Fullscreen", maximizeHeight = "MaximizeHeight"
    case undo = "Undo", initialFrame = "InitialFrame", hide = "Hide", minimize = "Minimize"
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

    // Vertical Thirds
    case topThird = "TopThird", topTwoThirds = "TopTwoThirds"
    case verticalCenterThird = "VerticalCenterThird"
    case bottomThird = "BottomThird", bottomTwoThirds = "BottomTwoThirds"

    // Screen Switching
    case nextScreen = "NextScreen", previousScreen = "PreviousScreen"

    // Size Adjustment
    case larger = "Larger", smaller = "Smaller"

    // Shrink
    case shrinkTop = "ShrinkTop", shrinkBottom = "ShrinkBottom", shrinkRight = "ShrinkRight", shrinkLeft = "ShrinkLeft"

    // Grow
    case growTop = "GrowTop", growBottom = "GrowBottom", growRight = "GrowRight", growLeft = "GrowLeft"

    // Move
    case moveUp = "MoveUp", moveDown = "MoveDown", moveRight = "MoveRight", moveLeft = "MoveLeft"

    // Custom Actions
    case custom = "Custom", cycle = "Cycle"

    // These are used in the menubar resize submenu & keybind configuratio
    static var general: [WindowDirection] { [.fullscreen, .maximize, .maximizeHeight, .almostMaximize, .center, .macOSCenter, .minimize, .hide] }
    static var halves: [WindowDirection] { [.topHalf, .verticalCenterHalf, .bottomHalf, .leftHalf, .horizontalCenterHalf, .rightHalf] }
    static var quarters: [WindowDirection] { [.topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter] }
    static var horizontalThirds: [WindowDirection] { [.rightThird, .rightTwoThirds, .horizontalCenterThird, .leftTwoThirds, .leftThird] }
    static var verticalThirds: [WindowDirection] { [.topThird, .topTwoThirds, .verticalCenterThird, .bottomTwoThirds, .bottomThird] }
    static var screenSwitching: [WindowDirection] { [.nextScreen, .previousScreen] }
    static var sizeAdjustment: [WindowDirection] { [.larger, .smaller] }
    static var shrink: [WindowDirection] { [.shrinkTop, .shrinkBottom, .shrinkRight, .shrinkLeft] }
    static var grow: [WindowDirection] { [.growTop, .growBottom, .growRight, .growLeft] }
    static var move: [WindowDirection] { [.moveUp, .moveDown, .moveRight, .moveLeft] }
    static var more: [WindowDirection] { [.initialFrame, .undo, .custom, .cycle] }

    // Computed properties for checking conditions
    var willChangeScreen: Bool { WindowDirection.screenSwitching.contains(self) }
    var willAdjustSize: Bool { WindowDirection.sizeAdjustment.contains(self) }
    var willShrink: Bool { WindowDirection.shrink.contains(self) }
    var willGrow: Bool { WindowDirection.grow.contains(self) }
    var willMove: Bool { WindowDirection.move.contains(self) }

    var hasRadialMenuAngle: Bool {
        let noAngleActions: [WindowDirection] = [.noAction, .maximize, .center, .macOSCenter, .almostMaximize, .fullscreen, .minimize, .hide, .initialFrame, .undo, .cycle]
        return !(noAngleActions.contains(self) || willChangeScreen || willAdjustSize || willShrink || willGrow || willMove)
    }

    var shouldFillRadialMenu: Bool {
        [.maximize, .center, .macOSCenter, .almostMaximize, .fullscreen].contains(self)
    }

    var frameMultiplyValues: CGRect? {
        switch self {
        case .maximize: .init(x: 0, y: 0, width: 1.0, height: 1.0)
        case .maximizeHeight: .init(x: nil, y: nil, width: nil, height: 1.0)
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
