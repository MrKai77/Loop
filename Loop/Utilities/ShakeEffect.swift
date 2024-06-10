//
//  ShakeEffect.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-17.
//

import SwiftUI

struct ShakeEffect: GeometryEffect {
    func effectValue(size _: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: 3 * sin(position * 3 * .pi),
                y: 0
            )
        )
    }

    init(shakes: Int) {
        self.position = CGFloat(shakes)
    }

    var position: CGFloat
    var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }
}
