//
//  WindowDirection+LocalizedString.swift
//  Loop
//
//  Created by phlpsong on 2024/3/31.
//

import Foundation
import Luminare

extension WindowDirection {
    var infoView: LuminareInfoView? {
        var result: LuminareInfoView?

        if self == .macOSCenter {
            result = .init("\(name) places windows slightly above the absolute center,\nwhich can be found more ergonomic.")
        }

        return result
    }

    var name: String {
        switch self {
        case .noAction:
            .init(localized: .init("Window Direction/Name: No Action", defaultValue: "No Action"))
        case .maximize:
            .init(localized: .init("Window Direction/Name: Maximize", defaultValue: "Maximize"))
        case .almostMaximize:
            .init(localized: .init("Window Direction/Name: Almost Maximize", defaultValue: "Almost Maximize"))
        case .fullscreen:
            .init(localized: .init("Window Direction/Name: Fullscreen", defaultValue: "Fullscreen"))
        case .undo:
            .init(localized: .init("Window Direction/Name: Undo", defaultValue: "Undo"))
        case .initialFrame:
            .init(localized: .init("Window Direction/Name: Initial Frame", defaultValue: "Initial Frame"))
        case .hide:
            .init(localized: .init("Window Direction/Name: Hide", defaultValue: "Hide"))
        case .minimize:
            .init(localized: .init("Window Direction/Name: Minimize", defaultValue: "Minimize"))
        case .macOSCenter:
            .init(localized: .init("Window Direction/Name: macOS Center", defaultValue: "macOS Center"))
        case .center:
            .init(localized: .init("Window Direction/Name: Center", defaultValue: "Center"))
        case .topHalf:
            .init(localized: .init("Window Direction/Name: Top Half", defaultValue: "Top Half"))
        case .rightHalf:
            .init(localized: .init("Window Direction/Name: Right Half", defaultValue: "Right Half"))
        case .bottomHalf:
            .init(localized: .init("Window Direction/Name: Bottom Half", defaultValue: "Bottom Half"))
        case .leftHalf:
            .init(localized: .init("Window Direction/Name: Left Half", defaultValue: "Left Half"))
        case .topLeftQuarter:
            .init(localized: .init("Window Direction/Name: Top Left Quarter", defaultValue: "Top Left Quarter"))
        case .topRightQuarter:
            .init(localized: .init("Window Direction/Name: Top Right Quarter", defaultValue: "Top Right Quarter"))
        case .bottomRightQuarter:
            .init(localized: .init("Window Direction/Name: Bottom Right Quarter", defaultValue: "Bottom Right Quarter"))
        case .bottomLeftQuarter:
            .init(localized: .init("Window Direction/Name: Bottom Left Quarter", defaultValue: "Bottom Left Quarter"))
        case .rightThird:
            .init(localized: .init("Window Direction/Name: Right Third", defaultValue: "Right Third"))
        case .rightTwoThirds:
            .init(localized: .init("Window Direction/Name: Right Two Thirds", defaultValue: "Right Two Thirds"))
        case .horizontalCenterThird:
            .init(localized: .init("Window Direction/Name: Horizontal Center Third", defaultValue: "Horizontal Center Third"))
        case .leftThird:
            .init(localized: .init("Window Direction/Name: Left Third", defaultValue: "Left Third"))
        case .leftTwoThirds:
            .init(localized: .init("Window Direction/Name: Left Two Thirds", defaultValue: "Left Two Thirds"))
        case .topThird:
            .init(localized: .init("Window Direction/Name: Top Third", defaultValue: "Top Third"))
        case .topTwoThirds:
            .init(localized: .init("Window Direction/Name: Top Two Thirds", defaultValue: "Top Two Thirds"))
        case .verticalCenterThird:
            .init(localized: .init("Window Direction/Name: Vertical Center Third", defaultValue: "Vertical Center Third"))
        case .bottomThird:
            .init(localized: .init("Window Direction/Name: Bottom Third", defaultValue: "Bottom Third"))
        case .bottomTwoThirds:
            .init(localized: .init("Window Direction/Name: Bottom Two Thirds", defaultValue: "Bottom Two Thirds"))
        case .nextScreen:
            .init(localized: .init("Window Direction/Name: Next Screen", defaultValue: "Next Screen"))
        case .previousScreen:
            .init(localized: .init("Window Direction/Name: Previous Screen", defaultValue: "Previous Screen"))
        case .larger:
            .init(localized: .init("Window Direction/Name: Larger", defaultValue: "Larger"))
        case .smaller:
            .init(localized: .init("Window Direction/Name: Smaller", defaultValue: "Smaller"))
        case .shrinkTop:
            .init(localized: .init("Window Direction/Name: Shrink Top", defaultValue: "Shrink Top"))
        case .shrinkBottom:
            .init(localized: .init("Window Direction/Name: Shrink Bottom", defaultValue: "Shrink Bottom"))
        case .shrinkRight:
            .init(localized: .init("Window Direction/Name: Shrink Right", defaultValue: "Shrink Right"))
        case .shrinkLeft:
            .init(localized: .init("Window Direction/Name: Shrink Left", defaultValue: "Shrink Left"))
        case .growTop:
            .init(localized: .init("Window Direction/Name: Grow Top", defaultValue: "Grow Top"))
        case .growBottom:
            .init(localized: .init("Window Direction/Name: Grow Bottom", defaultValue: "Grow Bottom"))
        case .growRight:
            .init(localized: .init("Window Direction/Name: Grow Right", defaultValue: "Grow Right"))
        case .growLeft:
            .init(localized: .init("Window Direction/Name: Grow Left", defaultValue: "Grow Left"))
        case .moveUp:
            .init(localized: .init("Window Direction/Name: Move Up", defaultValue: "Move Up"))
        case .moveDown:
            .init(localized: .init("Window Direction/Name: Move Down", defaultValue: "Move Down"))
        case .moveRight:
            .init(localized: .init("Window Direction/Name: Move Right", defaultValue: "Move Right"))
        case .moveLeft:
            .init(localized: .init("Window Direction/Name: Move Left", defaultValue: "Move Left"))
        case .custom:
            .init(localized: .init("Window Direction/Name: Custom", defaultValue: "Custom"))
        case .cycle:
            .init(localized: .init("Window Direction/Name: Cycle", defaultValue: "Cycle"))
        }
    }
}
