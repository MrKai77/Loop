//
//  DirectionSelectorCircleSegment.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-19.
//

import SwiftUI

struct DirectionSelectorCircleSegment: View {
    var startingAngle: Double = 0
    let isActive: Bool
    let radialMenuSize: CGFloat

    init(_ resizePosition: WindowDirection, _ activeResizePosition: WindowDirection, _ radialMenuSize: CGFloat) {
        if let angle = resizePosition.radialMenuAngle {
            self.startingAngle = angle - 90 - 22.5
        }
        if resizePosition == activeResizePosition {
            isActive = true
        } else {
            isActive = false
        }
        self.radialMenuSize = radialMenuSize
    }

    var body: some View {
        Path { path in
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
                startAngle: .degrees(startingAngle),
                endAngle: .degrees(startingAngle+45),
                clockwise: false
            )
        }
        .foregroundColor(isActive ? Color.black : Color.clear)
    }
}
