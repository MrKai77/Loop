//
//  AnimationConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-27.
//

import SwiftUI
import Defaults

enum AnimationConfiguration: Int, Defaults.Serializable, CaseIterable, Identifiable {
    var id: Self { return self }

    case smooth = 0
    case fast = 1
    case instant = 2

    var name: String {
        switch self {
        case .smooth:   "Smooth"
        case .fast:     "Fast"
        case .instant:  "Instant"
        }
    }

//    var previewWindowAnimation: Animation? {
//        switch self {
//        case .smooth:   .interpolatingSpring(duration: 0.3, bounce: 0.15, initialVelocity: 1/2)
//        case .fast:     .interpolatingSpring(duration: 0.2, bounce: 0.1, initialVelocity: 1/2)
//        case .instant:  nil
//        }
//    }

    var radialMenuAnimation: Animation {
        switch self {
        case .smooth:   .easeOut
        case .fast:     .easeOut(duration: 0.2)
        case .instant:  .easeOut(duration: 0.1)
        }
    }
}
