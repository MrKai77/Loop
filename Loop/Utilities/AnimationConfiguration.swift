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
        case .smooth:   String(localized: "Smooth", comment: "An animation configuration")
        case .fast:     String(localized: "Fast", comment: "An animation configuration")
        case .instant:  String(localized: "Instant", comment: "An animation configuration")
        }
    }

    var previewTimingFunction: CAMediaTimingFunction {
        switch self {
        case .smooth:   CAMediaTimingFunction(controlPoints: 0, 0.26, 0.45, 1)
        case .fast:     CAMediaTimingFunction(controlPoints: 0.22, 1, 0.47, 1)
        case .instant:  CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
        }
    }

    var radialMenuSize: Animation {
        switch self {
        case .smooth:   .easeOut(duration: 0.2)
        case .fast:     .easeOut(duration: 0.2)
        case .instant:  .easeOut(duration: 0.1)
        }
    }

    var radialMenuAngle: Animation {
        Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.2)
    }
}
