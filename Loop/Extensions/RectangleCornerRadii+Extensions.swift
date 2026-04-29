//
//  RectangleCornerRadii+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2025-11-25.
//

import SwiftUI

extension RectangleCornerRadii {
    static let zero: RectangleCornerRadii = .init(
        topLeading: 0,
        bottomLeading: 0,
        bottomTrailing: 0,
        topTrailing: 0
    )

    func inset(by amount: CGFloat, minRadius: CGFloat = 0) -> RectangleCornerRadii {
        RectangleCornerRadii(
            topLeading: max(topLeading - amount, minRadius),
            bottomLeading: max(bottomLeading - amount, minRadius),
            bottomTrailing: max(bottomTrailing - amount, minRadius),
            topTrailing: max(topTrailing - amount, minRadius)
        )
    }
}
