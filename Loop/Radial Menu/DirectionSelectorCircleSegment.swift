//
//  DirectionSelectorCircleSegment.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-19.
//

import SwiftUI

struct DirectionSelectorCircleSegment: Shape {
    var angle: Double = .zero
    let radialMenuSize: CGFloat

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func path(in _: CGRect) -> Path {
        var path = Path()

        path.move(
            to: CGPoint(
                x: radialMenuSize / 2,
                y: radialMenuSize / 2
            )
        )
        path.addArc(
            center: CGPoint(
                x: radialMenuSize / 2,
                y: radialMenuSize / 2
            ),
            radius: radialMenuSize,
            startAngle: .degrees(angle - 22.5),
            endAngle: .degrees(angle + 22.5),
            clockwise: false
        )

        return path
    }
}
