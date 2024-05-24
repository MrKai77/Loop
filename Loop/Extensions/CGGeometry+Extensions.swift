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

    func flipY(maxY: CGFloat) -> CGPoint {
        CGPoint(x: self.x, y: maxY - self.y)
    }

    func flipY(screen: NSScreen) -> CGPoint {
        return flipY(maxY: screen.frame.maxY)
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

    func approximatelyEqual(to size: CGSize, tolerance: CGFloat = 10) -> Bool {
        return abs(width - size.width) < tolerance && abs(height - size.height) < tolerance
    }
}

extension CGRect {
    func flipY(screen: NSScreen) -> CGRect {
        return flipY(maxY: screen.frame.maxY)
    }

    func flipY(maxY: CGFloat) -> CGRect {
        CGRect(
            x: self.minX,
            y: maxY - self.maxY,
            width: self.width,
            height: self.height
        )
    }

    func padding(_ sides: Edge.Set, _ amount: CGFloat) -> CGRect {
        var rect = self

        if sides.contains(.top) {
            rect.origin.y += amount
            rect.size.height -= amount
        }

        if sides.contains(.bottom) {
            rect.size.height -= amount
        }

        if sides.contains(.leading) {
            rect.origin.x += amount
            rect.size.width -= amount
        }

        if sides.contains(.trailing) {
            rect.size.width -= amount
        }

        return rect
    }

    func approximatelyEqual(to rect: CGRect, tolerance: CGFloat = 10) -> Bool {
        return abs(origin.x - rect.origin.x) < tolerance &&
                abs(origin.y - rect.origin.y) < tolerance &&
                abs(width - rect.width) < tolerance &&
                abs(height - rect.height) < tolerance
    }

    func pushBottomRightPointInside(_ rect2: CGRect) -> CGRect {
        var result = self

        if result.maxX > rect2.maxX {
            result.origin.x = rect2.maxX - result.width
        }

        if result.maxY > rect2.maxY {
            result.origin.y = rect2.maxY - result.height
        }

        return result
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

    var center: CGPoint {
        CGPoint(x: self.midX, y: self.midY)
    }

    func inset(by amount: CGFloat, minSize: CGSize) -> CGRect {
        // Respect minimum width and height
        let insettedWidth = max(minSize.width, self.width - 2 * amount)
        let insettedHeight = max(minSize.height, self.height - 2 * amount)

        // Calculate the new inset rectangle
        let newX = self.midX - insettedWidth / 2
        let newY = self.midY - insettedHeight / 2

        return CGRect(
            x: newX,
            y: newY,
            width: insettedWidth,
            height: insettedHeight
        )
    }

    func getEdgesTouchingBounds(_ rect2: CGRect) -> Edge.Set {
        var result: Edge.Set = []

        if self.minX.approximatelyEquals(to: rect2.minX) {
            result.insert(.leading)
        }

        if self.minY.approximatelyEquals(to: rect2.minY) {
            result.insert(.top)
        }

        if self.maxX.approximatelyEquals(to: rect2.maxX) {
            result.insert(.trailing)
        }

        if self.maxY.approximatelyEquals(to: rect2.maxY) {
            result.insert(.bottom)
        }

        return result
    }
}
