//
//  RadialMenuDirectionSelector.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-19.
//

import SwiftUI
import Defaults

struct RadialMenuDirectionSelectorView: View {
    @Default(.radialMenuCornerRadius) var radialMenuCornerRadius

    let activeAngle: WindowDirection
    let radialMenuSize: CGFloat

    init(activeAngle: WindowDirection, size: CGFloat) {
        self.activeAngle = activeAngle
        self.radialMenuSize = size
    }

    var body: some View {
        if activeAngle == .maximize {
            Color.white
        } else {
            if radialMenuCornerRadius < 40 {
                // This is used when the user configures the radial menu to be a square
                Color.clear
                    .overlay {
                        HStack(spacing: 0) {
                            VStack(spacing: 0) {
                                DirectionSelectorSquareSegment(.topLeftQuarter, activeAngle, radialMenuSize)
                                DirectionSelectorSquareSegment(.cycleLeft, activeAngle, radialMenuSize)
                                DirectionSelectorSquareSegment(.bottomLeftQuarter, activeAngle, radialMenuSize)
                            }
                            VStack(spacing: 0) {
                                DirectionSelectorSquareSegment(.cycleTop, activeAngle, radialMenuSize)
                                Spacer().frame(width: radialMenuSize/3, height: radialMenuSize/3)
                                DirectionSelectorSquareSegment(.cycleBottom, activeAngle, radialMenuSize)
                            }
                            VStack(spacing: 0) {
                                DirectionSelectorSquareSegment(.topRightQuarter, activeAngle, radialMenuSize)
                                DirectionSelectorSquareSegment(.cycleRight, activeAngle, radialMenuSize)
                                DirectionSelectorSquareSegment(.bottomRightQuarter, activeAngle, radialMenuSize)
                            }
                        }
                    }
            } else {
                // This is used when the user configures the radial menu to be a circle
                Color.clear
                    .overlay {
                        DirectionSelectorCircleSegment(.cycleRight, activeAngle, radialMenuSize)
                        DirectionSelectorCircleSegment(.bottomRightQuarter, activeAngle, radialMenuSize)
                        DirectionSelectorCircleSegment(.cycleBottom, activeAngle, radialMenuSize)
                        DirectionSelectorCircleSegment(.bottomLeftQuarter, activeAngle, radialMenuSize)
                        DirectionSelectorCircleSegment(.cycleLeft, activeAngle, radialMenuSize)
                        DirectionSelectorCircleSegment(.topLeftQuarter, activeAngle, radialMenuSize)
                        DirectionSelectorCircleSegment(.cycleTop, activeAngle, radialMenuSize)
                        DirectionSelectorCircleSegment(.topRightQuarter, activeAngle, radialMenuSize)
                    }
            }
        }
    }
}
