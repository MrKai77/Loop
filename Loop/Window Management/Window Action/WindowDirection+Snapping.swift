//
//  WindowDirection+Snapping.swift
//  Loop
//
//  Created by Kai Azim on 2024-06-09.
//

import Foundation

extension WindowDirection {
    static func getSnapDirection(
        mouseLocation: CGPoint,
        currentDirection: WindowDirection,
        screenFrame: CGRect,
        ignoredFrame: CGRect
    ) -> WindowDirection {
        var newDirection: WindowDirection = .noAction

        if mouseLocation.x < ignoredFrame.minX {
            newDirection = WindowDirection.processLeftSnap(mouseLocation, screenFrame)
        } else if mouseLocation.x > ignoredFrame.maxX {
            newDirection = WindowDirection.processRightSnap(mouseLocation, screenFrame)
        } else if mouseLocation.y < ignoredFrame.minY {
            newDirection = WindowDirection.processTopSnap(mouseLocation, screenFrame)
        } else if mouseLocation.y > ignoredFrame.maxY {
            newDirection = WindowDirection.processBottomSnap(mouseLocation, screenFrame, currentDirection)
        }

        return newDirection
    }

    private static func processLeftSnap(
        _ mouseLocation: CGPoint,
        _ screenFrame: CGRect
    ) -> WindowDirection {
        let mouseY = mouseLocation.y
        let maxY = screenFrame.maxY
        let height = screenFrame.height

        if mouseY < maxY - (height * 7 / 8) {
            return .topLeftQuarter
        }
        if mouseY > maxY - (height * 1 / 8) {
            return .bottomLeftQuarter
        }
        return .leftHalf
    }

    private static func processRightSnap(
        _ mouseLocation: CGPoint,
        _ screenFrame: CGRect
    ) -> WindowDirection {
        let mouseY = mouseLocation.y
        let maxY = screenFrame.maxY
        let height = screenFrame.height

        if mouseY < maxY - (height * 7 / 8) {
            return .topRightQuarter
        }
        if mouseY > maxY - (height * 1 / 8) {
            return .bottomRightQuarter
        }
        return .rightHalf
    }

    private static func processTopSnap(
        _ mouseLocation: CGPoint,
        _ screenFrame: CGRect
    ) -> WindowDirection {
        let mouseX = mouseLocation.x
        let maxX = screenFrame.maxX
        let width = screenFrame.width

        if mouseX < maxX - (width * 4 / 5) || mouseX > maxX - (width * 1 / 5) {
            return .topHalf
        }
        return .maximize
    }

    private static func processBottomSnap(
        _ mouseLocation: CGPoint,
        _ screenFrame: CGRect,
        _ currentDirection: WindowDirection
    ) -> WindowDirection {
        var newDirection: WindowDirection

        let mouseX = mouseLocation.x
        let maxX = screenFrame.maxX
        let width = screenFrame.width

        if mouseX < maxX - (width * 2 / 3) {
            newDirection = .leftThird
        } else if mouseX > maxX - (width * 1 / 3) {
            newDirection = .rightThird
        } else {
            // mouse is within 1/3 and 2/3 of the screen's width
            newDirection = .bottomHalf

            if currentDirection == .leftThird || currentDirection == .leftTwoThirds {
                newDirection = .leftTwoThirds
            } else if currentDirection == .rightThird || currentDirection == .rightTwoThirds {
                newDirection = .rightTwoThirds
            }
        }

        return newDirection
    }
}
