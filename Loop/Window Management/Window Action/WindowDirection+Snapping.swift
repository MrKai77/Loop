//
//  WindowDirection+Snapping.swift
//  Loop
//
//  Created by Kai Azim on 2024-06-09.
//

import Foundation

extension WindowDirection {
    private struct EdgeZoneDirections {
        /// < 1.05% - Extreme start corner (e.g., Top-Left)
        let nearCorner: WindowDirection

        /// 1.05% - 6.31% - Start half (e.g., Top Half)
        let half: WindowDirection

        /// 6.31% - 33.33% - Start third (e.g., Top Third)
        let third: WindowDirection

        /// 33.33% - 66.67% - Default center zone action (e.g., Full Edge Half)
        let edgeHalf: WindowDirection

        /// 33.33% - 66.67% - Center zone action when coming from a side zone
        let centerThird: WindowDirection

        /// 66.67% - 93.68% - End third (e.g., Bottom Third)
        let farThird: WindowDirection

        /// 93.68% - 98.95% - End half (e.g., Bottom Half)
        let farHalf: WindowDirection

        /// > 98.95% - Extreme end corner (e.g., Bottom-Left)
        let farCorner: WindowDirection

        /// Center zone actions available when cycling from `nearCorner`
        let cycleNear: (third: WindowDirection, twoThirds: WindowDirection)

        /// Center zone actions available when cycling from `farCorner`
        let cycleFar: (third: WindowDirection, twoThirds: WindowDirection)

        static let leftEdge = EdgeZoneDirections(
            nearCorner: .topLeftQuarter,
            half: .topHalf,
            third: .topThird,
            edgeHalf: .leftHalf,
            centerThird: .verticalCenterThird,
            farThird: .bottomThird,
            farHalf: .bottomHalf,
            farCorner: .bottomLeftQuarter,
            cycleNear: (third: .topThird, twoThirds: .topTwoThirds),
            cycleFar: (third: .bottomThird, twoThirds: .bottomTwoThirds)
        )

        static let rightEdge = EdgeZoneDirections(
            nearCorner: .topRightQuarter,
            half: .topHalf,
            third: .topThird,
            edgeHalf: .rightHalf,
            centerThird: .verticalCenterThird,
            farThird: .bottomThird,
            farHalf: .bottomHalf,
            farCorner: .bottomRightQuarter,
            cycleNear: (third: .topThird, twoThirds: .topTwoThirds),
            cycleFar: (third: .bottomThird, twoThirds: .bottomTwoThirds)
        )

        static let bottomEdge = EdgeZoneDirections(
            nearCorner: .bottomLeftQuarter,
            half: .leftHalf,
            third: .leftThird,
            edgeHalf: .bottomHalf,
            centerThird: .horizontalCenterThird,
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
        if mouseLocation.x < ignoredFrame.minX {
            return WindowDirection.processEdgeSnap(
                mousePos: mouseLocation.y,
                axisMax: screenFrame.maxY,
                axisLength: screenFrame.height,
                currentDirection: currentDirection,
                zones: .leftEdge
            )
        }

        if mouseLocation.x > ignoredFrame.maxX {
            return WindowDirection.processEdgeSnap(
                mousePos: mouseLocation.y,
                axisMax: screenFrame.maxY,
                axisLength: screenFrame.height,
                currentDirection: currentDirection,
                zones: .rightEdge
            )
        }

        if mouseLocation.y < ignoredFrame.minY {
            return WindowDirection.processTopSnap(mouseLocation, screenFrame)
        }

        if mouseLocation.y > ignoredFrame.maxY {
            return WindowDirection.processEdgeSnap(
                mousePos: mouseLocation.x,
                axisMax: screenFrame.maxX,
                axisLength: screenFrame.width,
                currentDirection: currentDirection,
                zones: .bottomEdge
            )
        }

        return .noAction
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

        // Center zone: results are stable once set.
        // If already showing a center-zone result, keep it.
        // Center zone results with sticky or transition logic
        if currentDirection == zones.edgeHalf {
            return currentDirection
        }

        let centerMid = axisMax - (axisLength * 0.5)
        let threshold = axisLength * 0.05 // 5% of screen dimension

        if currentDirection == zones.centerThird {
            if mousePos < centerMid - threshold {
                return zones.cycleNear.twoThirds
            } else if mousePos > centerMid + threshold {
                return zones.cycleFar.twoThirds
            }
            return currentDirection
        }

        if currentDirection == zones.cycleNear.twoThirds {
            if mousePos > centerMid {
                return zones.centerThird
            }
            return currentDirection
        }

        if currentDirection == zones.cycleFar.twoThirds {
            if mousePos < centerMid {
                return zones.centerThird
            }
            return currentDirection
        }

        // From a corner → twoThirds
        if currentDirection == zones.nearCorner {
            return zones.cycleNear.twoThirds
        }
        if currentDirection == zones.farCorner {
            return zones.cycleFar.twoThirds
        }

        // From a half/third outer zone → centerThird
        let outerZones: [WindowDirection] = [
            zones.half, zones.farHalf,
            zones.third, zones.farThird
        ]
        if outerZones.contains(currentDirection) {
            if mousePos < centerMid - threshold {
                return zones.cycleNear.twoThirds
            } else if mousePos > centerMid + threshold {
                return zones.cycleFar.twoThirds
            }
            return zones.centerThird
        }

        // Default: the edge's own half
        return zones.edgeHalf
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
