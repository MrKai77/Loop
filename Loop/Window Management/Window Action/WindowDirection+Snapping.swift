//
//  WindowDirection+Snapping.swift
//  Loop
//
//  Created by Kai Azim on 2024-06-09.
//

import Foundation

extension WindowDirection {
    private struct EdgeZoneDirections {
        let nearCorner: WindowDirection   // ~0-1% from start edge
        let half: WindowDirection         // ~1-6.3% from start edge
        let third: WindowDirection        // ~6.3-33% from start edge
        let centerDefault: WindowDirection // 33-67% center zone default
        let farThird: WindowDirection     // ~6.3-33% from end edge
        let farHalf: WindowDirection      // ~1-6.3% from end edge
        let farCorner: WindowDirection    // ~0-1% from end edge
        /// (third/twoThirds) pairs for cycling in the center zone
        let cycleNear: (third: WindowDirection, twoThirds: WindowDirection)
        let cycleFar: (third: WindowDirection, twoThirds: WindowDirection)

        /// Left edge: Y axis, corners are top-left/bottom-left
        static let leftEdge = EdgeZoneDirections(
            nearCorner: .topLeftQuarter,
            half: .topHalf,
            third: .topThird,
            centerDefault: .verticalCenterThird,
            farThird: .bottomThird,
            farHalf: .bottomHalf,
            farCorner: .bottomLeftQuarter,
            cycleNear: (third: .topThird, twoThirds: .topTwoThirds),
            cycleFar: (third: .bottomThird, twoThirds: .bottomTwoThirds)
        )

        /// Right edge: Y axis, corners are top-right/bottom-right
        static let rightEdge = EdgeZoneDirections(
            nearCorner: .topRightQuarter,
            half: .topHalf,
            third: .topThird,
            centerDefault: .verticalCenterThird,
            farThird: .bottomThird,
            farHalf: .bottomHalf,
            farCorner: .bottomRightQuarter,
            cycleNear: (third: .topThird, twoThirds: .topTwoThirds),
            cycleFar: (third: .bottomThird, twoThirds: .bottomTwoThirds)
        )

        /// Bottom edge: X axis, corners are bottom-left/bottom-right
        static let bottomEdge = EdgeZoneDirections(
            nearCorner: .bottomLeftQuarter,
            half: .leftHalf,
            third: .leftThird,
            centerDefault: .horizontalCenterThird,
            farThird: .rightThird,
            farHalf: .rightHalf,
            farCorner: .bottomRightQuarter,
            cycleNear: (third: .leftThird, twoThirds: .leftTwoThirds),
            cycleFar: (third: .rightThird, twoThirds: .rightTwoThirds)
        )
    }

    static func getSnapDirection(
        mouseLocation: CGPoint,
        currentDirection: WindowDirection,
        screenFrame: CGRect,
        ignoredFrame: CGRect
    ) -> WindowDirection {
        var newDirection: WindowDirection = .noAction

        if mouseLocation.x < ignoredFrame.minX {
            newDirection = WindowDirection.processEdgeSnap(
                mousePos: mouseLocation.y,
                axisMax: screenFrame.maxY,
                axisLength: screenFrame.height,
                currentDirection: currentDirection,
                zones: .leftEdge
            )
        } else if mouseLocation.x > ignoredFrame.maxX {
            newDirection = WindowDirection.processEdgeSnap(
                mousePos: mouseLocation.y,
                axisMax: screenFrame.maxY,
                axisLength: screenFrame.height,
                currentDirection: currentDirection,
                zones: .rightEdge
            )
        } else if mouseLocation.y < ignoredFrame.minY {
            newDirection = WindowDirection.processTopSnap(mouseLocation, screenFrame)
        } else if mouseLocation.y > ignoredFrame.maxY {
            newDirection = WindowDirection.processEdgeSnap(
                mousePos: mouseLocation.x,
                axisMax: screenFrame.maxX,
                axisLength: screenFrame.width,
                currentDirection: currentDirection,
                zones: .bottomEdge
            )
        }

        return newDirection
    }

    private static func processEdgeSnap(
        mousePos: CGFloat,
        axisMax: CGFloat,
        axisLength: CGFloat,
        currentDirection: WindowDirection,
        zones: EdgeZoneDirections
    ) -> WindowDirection {
        // Near edge ~1% (1/95): corner
        if mousePos < axisMax - (axisLength * 94 / 95) {
            return zones.nearCorner
        }

        // Near edge ~1%-6.3% (1/95 to 6/95): half
        if mousePos < axisMax - (axisLength * 89 / 95) {
            return zones.half
        }

        // Near edge 6.3%-33% (6/95 to 1/3): third
        if mousePos < axisMax - (axisLength * 2 / 3) {
            return zones.third
        }

        // Far edge ~1% (1/95): corner
        if mousePos > axisMax - (axisLength * 1 / 95) {
            return zones.farCorner
        }

        // Far edge ~1%-6.3% (1/95 to 6/95): half
        if mousePos > axisMax - (axisLength * 6 / 95) {
            return zones.farHalf
        }

        // Far edge 6.3%-33% (6/95 to 1/3): third
        if mousePos > axisMax - (axisLength * 1 / 3) {
            return zones.farThird
        }

        // Center zone: default third, cycle to two-thirds
        if currentDirection == zones.cycleNear.third || currentDirection == zones.cycleNear.twoThirds {
            return zones.cycleNear.twoThirds
        }
        if currentDirection == zones.cycleFar.third || currentDirection == zones.cycleFar.twoThirds {
            return zones.cycleFar.twoThirds
        }

        return zones.centerDefault
    }

    private static func processTopSnap(
        _ mouseLocation: CGPoint,
        _ screenFrame: CGRect
    ) -> WindowDirection {
        let mouseX = mouseLocation.x
        let maxX = screenFrame.maxX
        let width = screenFrame.width

        // Outer 1/5 edges (0-20% and 80-100%): top half
        if mouseX < maxX - (width * 4 / 5) || mouseX > maxX - (width * 1 / 5) {
            return .topHalf
        }

        // Center zone (20-80%): maximize
        return .maximize
    }
}
