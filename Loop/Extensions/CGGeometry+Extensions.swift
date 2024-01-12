//
//  CGPoint+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import SwiftUI

extension CGFloat {
    func approximatelyEquals(to comparison: CGFloat, tolerance: CGFloat = 10) -> Bool {
        return abs(self - comparison) < tolerance
    }
}

extension CGPoint {
    func angle(to comparisonPoint: CGPoint) -> CGFloat {
        let originX = comparisonPoint.x - x
        let originY = comparisonPoint.y - y
        let bearingRadians = -atan2f(Float(originY), Float(originX))

        return CGFloat(bearingRadians)
    }

    func distanceSquared(to comparisonPoint: CGPoint) -> CGFloat {
        let from = CGPoint(x: x, y: y)
        return (from.x - comparisonPoint.x)
            * (from.x - comparisonPoint.x)
            + (from.y - comparisonPoint.y)
            * (from.y - comparisonPoint.y)
    }

    var flipY: CGPoint? {
        guard let screen = NSScreen.screenWithMouse else { return nil }
        return CGPoint(x: self.x, y: screen.frame.maxY - self.y)
    }

    func approximatelyEqual(to point: CGPoint, tolerance: CGFloat = 10) -> Bool {
        abs(x - point.x) < tolerance &&
        abs(y - point.y) < tolerance
    }
}

extension CGSize {
    var area: CGFloat {
        self.width * self.height
    }
}

extension CGRect {
    var flipY: CGRect? {
        guard let screen = NSScreen.screenWithMouse else { return nil }
        return CGRect(
            x: self.minX,
            y: screen.frame.maxY - self.maxY,
            width: self.width,
            height: self.height)
    }

    mutating func inset(_ side: Edge, amount: CGFloat) {
        switch side {
        case .top:
            self.origin.y += amount
            self.size.height -= amount
        case .leading:
            self.origin.x += amount
            self.size.width -= amount
        case .bottom:
            self.size.height -= amount
        case .trailing:
            self.size.width -= amount
        }
    }

    func approximatelyEqual(to rect: CGRect, tolerance: CGFloat = 10) -> Bool {
        abs(origin.x - rect.origin.x) < tolerance && abs(origin.y - rect.origin.y) < tolerance &&
        abs(width - rect.width) < tolerance && abs(height - rect.height) < tolerance
    }

    var topLeftPoint: CGPoint {
        CGPoint(x: self.minX, y: self.minY)
    }

    var topRightPoint: CGPoint {
        CGPoint(x: self.maxX, y: self.minY)
    }

    var bottomLeftPoint: CGPoint {
        CGPoint(x: self.minX, y: self.maxY)
    }

    var bottomRightPoint: CGPoint {
        CGPoint(x: self.maxX, y: self.maxY)
    }
}
