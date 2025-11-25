//
//  RectangleCornerRadii+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2025-11-25.
//

import SwiftUI

extension RectangleCornerRadii {
    func inset(by amount: CGFloat, minRadius: CGFloat = 0) -> RectangleCornerRadii {
        RectangleCornerRadii(
            topLeading: max(topLeading - amount, minRadius),
            bottomLeading: max(bottomLeading - amount, minRadius),
            bottomTrailing: max(bottomTrailing - amount, minRadius),
            topTrailing: max(topTrailing - amount, minRadius)
        )
    }
}
