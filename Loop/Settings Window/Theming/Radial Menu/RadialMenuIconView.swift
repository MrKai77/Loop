//
//  RadialMenuIconView.swift
//  Loop
//
//  Created by Kai Azim on 2025-12-08.
//

import SwiftUI
import Defaults

struct RadialMenuIconView: View {
    private static let size: CGFloat = 18.0
    private static let normalSize: CGFloat = 100.0
    private static var miniScaleFactor: CGFloat {
        Self.size / Self.normalSize
    }
    
    @Default(.radialMenuCornerRadius) private var radialMenuCornerRadius
    @Default(.radialMenuThickness) private var radialMenuThickness
    
    private var cornerRadius: CGFloat {
        radialMenuCornerRadius * Self.miniScaleFactor
    }
    
    private var thickness: CGFloat {
        radialMenuThickness * Self.miniScaleFactor + 1
    }
    
    let totalItems: Int
    let index: Int
    
    private var shouldFillRadialMenu: Bool {
        index == totalItems - 1
    }
    
    private var degreesPerDirection: CGFloat {
        360.0 / Double(totalItems - 1)
    }
    
    var body: some View {
        Rectangle()
            .mask {
                border
                    .opacity(0.5)

                angleIndicator
            }
        .frame(width: 18, height: 18)
        .drawingGroup()
    }
    
    private var angleIndicator: some View {
        ZStack {
            if shouldFillRadialMenu {
                Color.white
            } else {
                if cornerRadius >= 18.0 / 2.0 {
                    DirectionSelectorCircleSegment(
                        angle: Double(index) * degreesPerDirection - 90.0,
                        radialMenuSize: 18
                    )
                } else {
                    DirectionSelectorSquareSegment(
                        angle: Double(index) * degreesPerDirection - 90.0,
                        radialMenuCornerRadius: cornerRadius,
                        radialMenuThickness: thickness
                    )
                }
            }
        }
        .foregroundStyle(.white)
        .mask {
            RoundedRectangle(cornerRadius: cornerRadius)
                .inset(by: thickness / 2)
                .stroke(lineWidth: thickness)
                .foregroundStyle(.white)
        }
    }
    
    private var border: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(lineWidth: 1)
            
            RoundedRectangle(cornerRadius: cornerRadius)
                .inset(by: thickness - 1)
                .strokeBorder(lineWidth: 1)
        }
        .foregroundStyle(.white)
    }
}
