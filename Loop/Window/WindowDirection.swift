//
//  WindowDirection.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import SwiftUI
import Defaults

// Enum that stores all possible resizing options
enum WindowDirection: CaseIterable {

    case noAction
    case maximize
    case center

    // Halves
    case topHalf
    case rightHalf
    case bottomHalf
    case leftHalf

    // Quarters
    case topLeftQuarter
    case topRightQuarter
    case bottomRightQuarter
    case bottomLeftQuarter

    // Horizontal Thirds
    case rightThird
    case rightTwoThirds
    case horizontalCenterThird
    case leftThird
    case leftTwoThirds

    // Vertical Thirds
    case topThird
    case topTwoThirds
    case verticalCenterThird
    case bottomThird
    case bottomTwoThirds

    var nextPreviewDirection: WindowDirection {
        switch self {
        case .noAction:             .topHalf
        case .topHalf:              .topRightQuarter
        case .topRightQuarter:      .rightHalf
        case .rightHalf:            .bottomRightQuarter
        case .bottomRightQuarter:   .bottomHalf
        case .bottomHalf:           .bottomLeftQuarter
        case .bottomLeftQuarter:    .leftHalf
        case .leftHalf:             .topLeftQuarter
        case .topLeftQuarter:       .maximize
        case .maximize:             .noAction
        default:                    .noAction
        }
    }

    var radialMenuAngle: Double? {
        switch self {
        case .topHalf:              0
        case .topRightQuarter:      45
        case .rightHalf:            90
        case .bottomRightQuarter:   135
        case .bottomHalf:           180
        case .bottomLeftQuarter:    225
        case .leftHalf:             270
        case .topLeftQuarter:       315
        case .maximize:             0
        default:                    nil
        }
    }

    var name: String? {
        switch self {
        case .noAction:                 nil
        case .maximize:                 "Maximize"
        case .center:                   "Center"

        case .topHalf:                  "Top Half"
        case .rightHalf:                "Right Half"
        case .bottomHalf:               "Bottom Half"
        case .leftHalf:                 "Left Half"

        case .topLeftQuarter:           "Top Left Quarter"
        case .topRightQuarter:          "Top Right Quarter"
        case .bottomRightQuarter:       "Bottom Right Quarter"
        case .bottomLeftQuarter:        "Bottom Left Quarter"

        case .leftThird:                "Left Third"
        case .leftTwoThirds:            "Left Two Thirds"
        case .horizontalCenterThird:    "Horizontal Center Third"
        case .rightTwoThirds:           "Right Two Thirds"
        case .rightThird:               "Right Third"

        case .topThird:                  "Top Third"
        case .topTwoThirds:              "Top Two Thirds"
        case .verticalCenterThird:       "Vertical Center Third"
        case .bottomThird:               "Bottom Third"
        case .bottomTwoThirds:           "Bottom Two Thirds"
        }
    }

    var keybind: [Set<UInt16>] {
        switch self {
        case .noAction:                 [[]]
        case .maximize:                 Defaults[.maximizeKeybind]
        case .center:                   Defaults[.centerKeybind]

        case .topHalf:                  Defaults[.topHalfKeybind]
        case .rightHalf:                Defaults[.rightHalfKeybind]
        case .bottomHalf:               Defaults[.bottomHalfKeybind]
        case .leftHalf:                 Defaults[.leftHalfKeybind]

        case .topLeftQuarter:           Defaults[.topLeftQuarter]
        case .topRightQuarter:          Defaults[.topRightQuarter]
        case .bottomRightQuarter:       Defaults[.bottomRightQuarter]
        case .bottomLeftQuarter:        Defaults[.bottomLeftQuarter]

        case .leftThird:                Defaults[.leftThird]
        case .leftTwoThirds:            Defaults[.leftTwoThirds]
        case .horizontalCenterThird:    Defaults[.horizontalCenterThird]
        case .rightTwoThirds:           Defaults[.rightTwoThirds]
        case .rightThird:               Defaults[.rightThird]

        default:                        [[]]
        }
    }

    var edgesTouchingScreen: [Edge] {
        switch self {
        case .maximize:                 [.top, .bottom, .leading, .trailing]
        case .topHalf:                  [.top, .leading, .trailing]
        case .rightHalf:                [.top, .bottom, .trailing]
        case .bottomHalf:               [.bottom, .leading, .trailing]
        case .leftHalf:                 [.top, .bottom, .leading]
        case .topLeftQuarter:           [.top, .leading]
        case .topRightQuarter:          [.top, .trailing]
        case .bottomRightQuarter:       [.bottom, .trailing]
        case .bottomLeftQuarter:        [.bottom, .leading]
        case .rightThird:               [.top, .bottom, .trailing]
        case .rightTwoThirds:           [.top, .bottom, .trailing]
        case .horizontalCenterThird:    [.top, .bottom]
        case .leftThird:                [.top, .bottom, .leading]
        case .leftTwoThirds:            [.top, .bottom, .leading]
        case .topThird:                 [.top, .leading, .trailing]
        case .topTwoThirds:             [.top, .leading, .trailing]
        case .verticalCenterThird:      [.leading, .trailing]
        case .bottomThird:              [.bottom, .leading, .trailing]
        case .bottomTwoThirds:          [.bottom, .leading, .trailing]
        default:                        []
        }
    }

    static func snapDirection(mouseLocation: CGPoint, screenFrame: CGRect, ignoredFrame: CGRect) -> WindowDirection {

        if mouseLocation.x < ignoredFrame.minX {
            if mouseLocation.y < screenFrame.maxY * 1/4 {
                return .topLeftQuarter
            } else if mouseLocation.y > screenFrame.maxY * 3/4 {
                return .bottomLeftQuarter
            } else {
                return .leftHalf
            }
        } else if mouseLocation.x > ignoredFrame.maxX {
            if mouseLocation.y < screenFrame.maxY * 1/4 {
                return .topRightQuarter
            } else if mouseLocation.y > screenFrame.maxY * 3/4 {
                return .bottomRightQuarter
            } else {
                return .rightHalf
            }
        } else if mouseLocation.y < ignoredFrame.minY {
            if mouseLocation.x < screenFrame.maxX * 1/4 {
                return .topLeftQuarter
            } else if mouseLocation.x > screenFrame.maxX * 3/4 {
                return .topRightQuarter
            } else {
                return .maximize
            }
        } else if mouseLocation.y > ignoredFrame.maxY {
            if mouseLocation.x < screenFrame.maxX * 1/4 {
                return .bottomLeftQuarter
            } else if mouseLocation.x > screenFrame.maxX * 3/4 {
                return .bottomRightQuarter
            } else {
                return .maximize
            }
        }

        return .noAction
    }
}
