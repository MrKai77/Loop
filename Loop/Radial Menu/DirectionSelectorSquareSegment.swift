//
//  DirectionSelectorSquareSegment.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-19.
//

import SwiftUI

struct DirectionSelectorSquareSegment: View {
    let isActive: Bool
    let radialMenuSize: CGFloat

    init(_ resizePosition: WindowDirection, _ activeResizePosition: WindowDirection, _ radialMenuSize: CGFloat) {
        if resizePosition == activeResizePosition {
            isActive = true
        } else {
            isActive = false
        }
        self.radialMenuSize = radialMenuSize
    }

    var body: some View {
        Rectangle()
            .foregroundColor(isActive ? Color.black : Color.clear)
            .frame(width: radialMenuSize/3, height: radialMenuSize/3)
    }
}
