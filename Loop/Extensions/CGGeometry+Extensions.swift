//
//  CGGeometry+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import SwiftUI

extension CGFloat {
    func approximatelyEquals(to comparison: CGFloat, tolerance: CGFloat = 10) -> Bool {
        abs(self - comparison) < tolerance
    }
}

extension CGPoint {
    func angle(to comparisonPoint: CGPoint) -> CGFloat {
        let originX = comparisonPoint.x - x
        let originY = comparisonPoint.y - y
        let bearingRadians = -atan2f(Float(originY), Float(originX))

        return CGFloat(bearingRadians)
    }

    func distance(to comparisonPoint: CGPoint) -> CGFloat {
        let from = CGPoint(x: x, y: y)
        return sqrt(pow(from.x - comparisonPoint.x, 2) + pow(from.y - comparisonPoint.y, 2))
    }

    func flipY(maxY: CGFloat) -> CGPoint {
        CGPoint(x: x, y: maxY - y)
    }

    func flipY(screen: NSScreen) -> CGPoint {
        flipY(maxY: screen.frame.maxY)
    }

    func approximatelyEqual(to point: CGPoint, tolerance: CGFloat = 10) -> Bool {
        abs(x - point.x) < tolerance &&
            abs(y - point.y) < tolerance
    }
}

extension CGSize {
    var area: CGFloat {
        width * height
    }

    func approximatelyEqual(to size: CGSize, tolerance: CGFloat = 10) -> Bool {
        abs(width - size.width) < tolerance && abs(height - size.height) < tolerance
    }

    func center(inside parentRect: CGRect) -> CGRect {
        let parentRectCenter = parentRect.center
        let newX = parentRectCenter.x - width / 2
        let newY = parentRectCenter.y - height / 2

        return CGRect(
            x: newX,
            y: newY,
            width: width,
            height: height
        )
    }
}

extension CGRect {
    func flipY(screen: NSScreen) -> CGRect {
        flipY(maxY: screen.frame.maxY)
    }

    func flipY(maxY: CGFloat) -> CGRect {
        CGRect(
            x: minX,
            y: maxY - self.maxY,
            width: width,
            height: height
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
        abs(origin.x - rect.origin.x) < tolerance &&
            abs(origin.y - rect.origin.y) < tolerance &&
            abs(width - rect.width) < tolerance &&
            abs(height - rect.height) < tolerance
    }

    func pushInside(_ rect2: CGRect) -> CGRect {
        var result = self

        if result.minX < rect2.minX {
            result.origin.x = rect2.minX
        }

        if result.minY < rect2.minY {
            result.origin.y = rect2.minY
        }

        if result.maxX > rect2.maxX {
            result.origin.x = rect2.maxX - result.width
        }

        if result.maxY > rect2.maxY {
            result.origin.y = rect2.maxY - result.height
        }

        return result
    }

    var topLeftPoint: CGPoint {
        CGPoint(x: minX, y: minY)
    }

    var topRightPoint: CGPoint {
        CGPoint(x: maxX, y: minY)
    }

    var bottomLeftPoint: CGPoint {
        CGPoint(x: minX, y: maxY)
    }

    var bottomRightPoint: CGPoint {
        CGPoint(x: maxX, y: maxY)
    }

    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    func inset(by amount: CGFloat, minSize: CGSize) -> CGRect {
        // Respect minimum width and height
        let insettedWidth = max(minSize.width, width - 2 * amount)
        let insettedHeight = max(minSize.height, height - 2 * amount)

        // Calculate the new inset rectangle
        let newX = midX - insettedWidth / 2
        let newY = midY - insettedHeight / 2

        return CGRect(
            x: newX,
            y: newY,
            width: insettedWidth,
            height: insettedHeight
        )
    }

    func getEdgesTouchingBounds(_ rect2: CGRect) -> Edge.Set {
        var result: Edge.Set = []

        if minX.approximatelyEquals(to: rect2.minX) {
            result.insert(.leading)
        }

        if minY.approximatelyEquals(to: rect2.minY) {
            result.insert(.top)
        }

        if maxX.approximatelyEquals(to: rect2.maxX) {
            result.insert(.trailing)
        }

        if maxY.approximatelyEquals(to: rect2.maxY) {
            result.insert(.bottom)
        }

        return result
    }

    /// Returns a new rectangle with integer values for the origin and size.
    /// - Returns: A new rectangle with integer values for the origin and size.
    func integerRect() -> CGRect {
        CGRect(
            x: floor(minX),
            y: floor(minY),
            width: floor(width),
            height: floor(height)
        )
    }

    /// Returns true if the rectangle is finite, false otherwise.
    var isFinite: Bool {
        origin.x.isFinite &&
            origin.y.isFinite &&
            size.width.isFinite &&
            size.height.isFinite &&
            !isNull &&
            !isInfinite
    }
}
