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
        // Only enable thirds on the primary (longer) axis of the screen.
        // If the aspect ratio is close to square (within 4:3), enable thirds on both axes.
        // Otherwise, only the longer axis gets thirds; the shorter axis stays simple.
        let aspectRatio = screenFrame.width / screenFrame.height
        let isNearSquare = aspectRatio >= 3.0 / 4.0 && aspectRatio <= 4.0 / 3.0
        let verticalSimple = !isNearSquare && screenFrame.width > screenFrame.height
        let horizontalSimple = !isNearSquare && screenFrame.height > screenFrame.width

        if mouseLocation.x < ignoredFrame.minX {
            return WindowDirection.processEdgeSnap(
                mousePos: mouseLocation.y,
                axisMax: screenFrame.maxY,
                axisLength: screenFrame.height,
                currentDirection: currentDirection,
                zones: .leftEdge,
                simpleMode: verticalSimple
            )
        }

        if mouseLocation.x > ignoredFrame.maxX {
            return WindowDirection.processEdgeSnap(
                mousePos: mouseLocation.y,
                axisMax: screenFrame.maxY,
                axisLength: screenFrame.height,
                currentDirection: currentDirection,
                zones: .rightEdge,
                simpleMode: verticalSimple
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
                zones: .bottomEdge,
                simpleMode: horizontalSimple
            )
        }

        return .noAction
    }

    private static func processEdgeSnap(
        mousePos: CGFloat,
        axisMax: CGFloat,
        axisLength: CGFloat,
        currentDirection: WindowDirection,
        zones: EdgeZoneDirections,
        simpleMode: Bool
    ) -> WindowDirection {
        // Near edge ~0%-1% (0 to 1/95): corner
        if mousePos < axisMax - (axisLength * 94 / 95) {
            return zones.nearCorner
        }

        // Far edge ~99%-100% (94/95 to 1): corner
        if mousePos > axisMax - (axisLength * 1 / 95) {
            return zones.farCorner
        }

        // Simple mode: this is the shorter axis, so only corners + edge half.
        // No thirds, halves, or cycling logic needed.
        if simpleMode {
            return zones.edgeHalf
        }

        // Near edge ~1%-6.3% (1/95 to 6/95): half
        if mousePos < axisMax - (axisLength * 89 / 95) {
            return zones.half
        }

        // Near edge ~6.3%-33% (6/95 to 1/3): third
        if mousePos < axisMax - (axisLength * 2 / 3) {
            return zones.third
        }

        // Far edge ~93.7%-99% (89/95 to 94/95): half
        if mousePos > axisMax - (axisLength * 6 / 95) {
            return zones.farHalf
        }

        // Far edge ~67%-93.7% (2/3 to 89/95): third
        if mousePos > axisMax - (axisLength * 1 / 3) {
            return zones.farThird
        }

        // Center zone cycling logic.
        let centerMid = axisMax - (axisLength * 0.5)
        let threshold = axisLength * 0.05 // 5% of screen dimension

        // Keep the default edge-half stable once it has been selected.
        if currentDirection == zones.edgeHalf {
            return currentDirection
        }

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

        // Near edge ~0%-1% (0 to 1/95): corner
        if mouseX < maxX - (width * 94 / 95) {
            return .topLeftQuarter
        }

        // Near edge ~1%-20% (1/95 to 1/5): half
        if mouseX < maxX - (width * 4 / 5) {
            return .topHalf
        }

        // Far edge ~99%-100% (94/95 to 1): corner
        if mouseX > maxX - (width * 1 / 95) {
            return .topRightQuarter
        }

        // Far edge ~80%-99% (4/5 to 94/95): half
        if mouseX > maxX - (width * 1 / 5) {
            return .topHalf
        }

        // Center 20%-80%: maximize
        return .maximize
    }
}
