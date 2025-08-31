//
//  DirectionSelectorSquareSegment.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-19.
//

import SwiftUI

struct DirectionSelectorSquareSegment: View {
    var angle: Double = .zero
    let radialMenuCornerRadius: CGFloat
    let radialMenuThickness: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radialMenuCornerRadius)
                .trim(
                    from: Angle(degrees: angle - 22.5).normalized().degrees / 360.0,
                    to: Angle(degrees: angle + 22.5).normalized().degrees / 360.0
                )
                .stroke(.white, lineWidth: radialMenuThickness * 2)

            RoundedRectangle(cornerRadius: radialMenuCornerRadius)
                .trim(
                    from: Angle(degrees: angle - 180 - 22.5).normalized().degrees / 360.0,
                    to: Angle(degrees: angle - 180 + 22.5).normalized().degrees / 360.0
                )
                .stroke(.white, lineWidth: radialMenuThickness * 2)
                .rotationEffect(.degrees(180))
        }
    }
}
