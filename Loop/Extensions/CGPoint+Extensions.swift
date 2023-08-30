//
//  CGPoint+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import Foundation

// Add two extensions: one to detect the angle between two CGPoints and one to detect the distance
// This is used to calculate the distance and angle of the cursor from loop's radial menu.
extension CGPoint {
    func angle(to comparisonPoint: CGPoint) -> CGFloat {
        let originX = comparisonPoint.x - x
        let originY = comparisonPoint.y - y
        let bearingRadians = -atan2f(Float(originY), Float(originX))

        return CGFloat(bearingRadians)
    }

    func distanceSquared(to comparisonPoint: CGPoint) -> CGFloat {
        let from = CGPoint(x: x, y: y)
        return (from.x - comparisonPoint.x)
            * (from.x - comparisonPoint.x)
            + (from.y - comparisonPoint.y)
            * (from.y - comparisonPoint.y)
    }
}
