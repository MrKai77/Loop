//
//  DirectionSelectorCircleSegment.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-19.
//

import SwiftUI

struct DirectionSelectorCircleSegment: Shape {

    let radialMenuSize: CGFloat
    var angle: Double = .zero

    var animatableData: Double {
        get { self.angle }
        set { self.angle = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to:
                    CGPoint(
                        x: radialMenuSize/2,
                        y: radialMenuSize/2
                    )
        )
        path.addArc(
            center: CGPoint(x: radialMenuSize/2,
                            y: radialMenuSize/2),
            radius: radialMenuSize,
            startAngle: .degrees(angle - 22.5),
            endAngle: .degrees(angle + 22.5),
            clockwise: false
        )

        return path
    }
}
