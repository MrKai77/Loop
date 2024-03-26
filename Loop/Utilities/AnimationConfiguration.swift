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

    var previewTimingFunction: CAMediaTimingFunction {
        switch self {
        case .smooth:   CAMediaTimingFunction(controlPoints: 0, 0.52, 0.43, 1)
        case .fast:     CAMediaTimingFunction(controlPoints: 0.22, 1, 0.47, 1)
        case .instant:  CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
        }
    }

    var radialMenuAnimation: Animation {
        switch self {
        case .smooth:   .easeOut
        case .fast:     .easeOut(duration: 0.2)
        case .instant:  .easeOut(duration: 0.1)
        }
    }
}
