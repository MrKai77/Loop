//
//  WindowDirection+LocalizedString.swift
//  Loop
//
//  Created by phlpsong on 2024/3/31.
//

import Luminare
import SwiftUI

extension WindowDirection {
    var infoText: LocalizedStringKey? {
        switch self {
        case .macOSCenter: "\(name) places windows slightly above the absolute center,\nwhich can be found more ergonomic."
        default: nil
        }
    }

    var name: String {
        switch self {
        case .noAction:
            .init(localized: .init("Window Direction/Name: No Action", defaultValue: "No Action"))
        case .maximize:
            .init(localized: .init("Window Direction/Name: Maximize", defaultValue: "Maximize"))
        case .almostMaximize:
            .init(localized: .init("Window Direction/Name: Almost Maximize", defaultValue: "Almost Maximize"))
        case .maximizeHeight:
            .init(localized: .init("Window Direction/Name: Maximize Height", defaultValue: "Maximize Height"))
        case .maximizeWidth:
            .init(localized: .init("Window Direction/Name: Maximize Width", defaultValue: "Maximize Width"))
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
        case .minimizeOthers:
            .init(localized: .init("Window Direction/Name: Minimize Others", defaultValue: "Minimize Others"))
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
        case .horizontalCenterHalf:
            .init(localized: .init("Window Direction/Name: Horizontal Center Half", defaultValue: "Horizontal Center Half"))
        case .verticalCenterHalf:
            .init(localized: .init("Window Direction/Name: Vertical Center Half", defaultValue: "Vertical Center Half"))
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
        case .firstFourth:
            .init(localized: .init("Window Direction/Name: First Fourth", defaultValue: "First Fourth"))
        case .secondFourth:
            .init(localized: .init("Window Direction/Name: Second Fourth", defaultValue: "Second Fourth"))
        case .thirdFourth:
            .init(localized: .init("Window Direction/Name: Third Fourth", defaultValue: "Third Fourth"))
        case .fourthFourth:
            .init(localized: .init("Window Direction/Name: Fourth Fourth", defaultValue: "Fourth Fourth"))
        case .leftThreeFourths:
            .init(localized: .init("Window Direction/Name: Left Three Fourths", defaultValue: "Left Three Fourths"))
        case .rightThreeFourths:
            .init(localized: .init("Window Direction/Name: Right Three Fourths", defaultValue: "Right Three Fourths"))
        case .nextScreen:
            .init(localized: .init("Window Direction/Name: Next Screen", defaultValue: "Next Screen"))
        case .previousScreen:
            .init(localized: .init("Window Direction/Name: Previous Screen", defaultValue: "Previous Screen"))
        case .leftScreen:
            .init(localized: .init("Window Direction/Name: Left Screen", defaultValue: "Left Screen"))
        case .rightScreen:
            .init(localized: .init("Window Direction/Name: Right Screen", defaultValue: "Right Screen"))
        case .topScreen:
            .init(localized: .init("Window Direction/Name: Top Screen", defaultValue: "Top Screen"))
        case .bottomScreen:
            .init(localized: .init("Window Direction/Name: Bottom Screen", defaultValue: "Bottom Screen"))
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
        case .shrinkHorizontal:
            .init(localized: .init("Window Direction/Name: Shrink Horizontally", defaultValue: "Shrink Horizontally"))
        case .shrinkVertical:
            .init(localized: .init("Window Direction/Name: Shrink Vertically", defaultValue: "Shrink Vertically"))
        case .growTop:
            .init(localized: .init("Window Direction/Name: Grow Top", defaultValue: "Grow Top"))
        case .growBottom:
            .init(localized: .init("Window Direction/Name: Grow Bottom", defaultValue: "Grow Bottom"))
        case .growRight:
            .init(localized: .init("Window Direction/Name: Grow Right", defaultValue: "Grow Right"))
        case .growLeft:
            .init(localized: .init("Window Direction/Name: Grow Left", defaultValue: "Grow Left"))
        case .growHorizontal:
            .init(localized: .init("Window Direction/Name: Grow Horizontally", defaultValue: "Grow Horizontally"))
        case .growVertical:
            .init(localized: .init("Window Direction/Name: Grow Vertically", defaultValue: "Grow Vertically"))
        case .moveUp:
            .init(localized: .init("Window Direction/Name: Move Up", defaultValue: "Move Up"))
        case .moveDown:
            .init(localized: .init("Window Direction/Name: Move Down", defaultValue: "Move Down"))
        case .moveRight:
            .init(localized: .init("Window Direction/Name: Move Right", defaultValue: "Move Right"))
        case .moveLeft:
            .init(localized: .init("Window Direction/Name: Move Left", defaultValue: "Move Left"))
        case .stash:
            .init(localized: .init("Window Direction/Name: Stash", defaultValue: "Stash"))
        case .unstash:
            .init(localized: .init("Window Direction/Name: Unstash", defaultValue: "Unstash"))
        case .custom:
            .init(localized: .init("Window Direction/Name: Custom", defaultValue: "Custom"))
        case .cycle:
            .init(localized: .init("Window Direction/Name: Cycle", defaultValue: "Cycle"))
        }
    }
}
