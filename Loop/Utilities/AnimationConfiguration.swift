//
//  AnimationConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-27.
//

import Defaults
import SwiftUI

enum AnimationConfiguration: Int, Defaults.Serializable, CaseIterable, Identifiable, Codable {
    var id: Self { self }

    case smooth = 0
    case balanced = 1
    case fast = 2
    case quick = 3
    case instant = 4

    var name: LocalizedStringKey {
        switch self {
        case .smooth:
            "Fluid"
        case .balanced:
            "Relaxed"
        case .fast:
            "Snappy"
        case .quick:
            "Brisk"
        case .instant:
            "Instant"
        }
    }

    var previewTimingFunction: CAMediaTimingFunction? {
        switch self {
        case .smooth:
            CAMediaTimingFunction(controlPoints: 0, 0.26, 0.45, 1)
        case .balanced:
            CAMediaTimingFunction(controlPoints: 0.15, 0.8, 0.46, 1)
        case .fast:
            CAMediaTimingFunction(controlPoints: 0.22, 1, 0.47, 1)
        case .quick:
            CAMediaTimingFunction(controlPoints: 0.25, 1, 0.48, 1)
        case .instant:
            nil
        }
    }

    var previewTimingFunctionSwiftUI: Animation? {
        switch self {
        case .smooth:
            Animation.timingCurve(0, 0.26, 0.45, 1)
        case .balanced:
            Animation.timingCurve(0.15, 0.8, 0.46, 1)
        case .fast:
            Animation.timingCurve(0.22, 1, 0.47, 1)
        case .quick:
            Animation.timingCurve(0.25, 1, 0.48, 1)
        case .instant:
            nil
        }
    }

    var radialMenuSize: Animation {
        switch self {
        case .smooth:
            .easeOut(duration: 0.2)
        case .balanced:
            .easeOut(duration: 0.2)
        case .fast:
            .easeOut(duration: 0.2)
        case .quick:
            .easeOut(duration: 0.15)
        case .instant:
            .easeOut(duration: 0.1)
        }
    }

    var radialMenuAngle: Animation {
        Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.2)
    }
}
