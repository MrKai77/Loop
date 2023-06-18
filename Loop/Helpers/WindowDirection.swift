//
//  WindowDirection.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import SwiftUI

// Enum that stores all possible resizing options
enum WindowDirection: CaseIterable {
    
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
