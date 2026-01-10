//
//  AnimationConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-27.
//

import Defaults
import SwiftUI

enum AnimationConfiguration: Int, Defaults.Serializable, CaseIterable, Identifiable {
    var id: Self { self }

    case fluid = 0
    case relaxed = 1
    case snappy = 2
    case brisk = 3
    case instant = 4

    var name: LocalizedStringKey {
        switch self {
        case .fluid:
            "Fluid"
        case .relaxed:
            "Relaxed"
        case .snappy:
            "Snappy"
        case .brisk:
            "Brisk"
        case .instant:
            "Instant"
        }
    }

    // MARK: Preview Window

    var previewTimingFunction: CAMediaTimingFunction? {
        switch self {
        case .fluid:
            CAMediaTimingFunction(controlPoints: 0, 0.26, 0.45, 1)
        case .relaxed:
            CAMediaTimingFunction(controlPoints: 0.15, 0.8, 0.46, 1)
        case .snappy:
            CAMediaTimingFunction(controlPoints: 0.22, 1, 0.47, 1)
        case .brisk:
            CAMediaTimingFunction(controlPoints: 0.25, 1, 0.48, 1)
        case .instant:
            nil
        }
    }

    var previewTimingFunctionSwiftUI: Animation? {
        guard let points = previewTimingFunction?.controlPoints else {
            return nil
        }
        return .timingCurve(
            points.0.x,
            points.0.y,
            points.1.x,
            points.1.y,
            duration: previewTimingDuration
        )
    }

    var previewTimingDuration: TimeInterval {
        switch self {
        case .fluid:
            0.325
        case .relaxed:
            0.3
        case .snappy:
            0.25
        case .brisk:
            0.15
        case .instant:
            0
        }
    }

    // MARK: Radial Menu

    var radialMenuSize: Animation {
        switch self {
        case .fluid:
            .easeOut(duration: 0.2)
        case .relaxed:
            .easeOut(duration: 0.2)
        case .snappy:
            .easeOut(duration: 0.2)
        case .brisk:
            .easeOut(duration: 0.15)
        case .instant:
            .easeOut(duration: 0.1)
        }
    }

    var radialMenuAngle: Animation {
        if self == .instant {
            .linear(duration: 0)
        } else {
            .timingCurve(0.22, 1, 0.36, 1, duration: 0.2)
        }
    }

    var animateRadialMenuAppearance: Bool {
        self != .instant
    }
}

private extension CAMediaTimingFunction {
    var controlPoints: (CGPoint, CGPoint) {
        var c1: [Float] = [0, 0]
        var c2: [Float] = [0, 0]

        // 0 and 3 are the start/end points, so grab the center two points
        getControlPoint(at: 1, values: &c1)
        getControlPoint(at: 2, values: &c2)

        let c1x = CGFloat(c1[0])
        let c1y = CGFloat(c1[1])
        let c2x = CGFloat(c2[0])
        let c2y = CGFloat(c2[1])

        return (CGPoint(x: c1x, y: c1y), CGPoint(x: c2x, y: c2y))
    }
}
