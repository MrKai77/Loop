//
//  Angle+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import SwiftUI

extension Angle {
    func normalized() -> Angle {
        let degrees = (degrees.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)

        return Angle(degrees: degrees)
    }

    func angleDifference(to angle2: Angle) -> Angle {
        let angle1 = degrees
        let angle2 = angle2.degrees
        let diff: Double = (angle2 - angle1 + 180.0).truncatingRemainder(dividingBy: 360.0) - 180.0
        return Angle(degrees: diff < -180 ? diff + 360 : diff)
    }
}
