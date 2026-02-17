//
//  WindowFrameResolver.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-20.
//

import Defaults
import Scribe
import SwiftUI

@Loggable(style: .static)
enum WindowFrameResolver {
    typealias FrameResult = (frame: CGRect, sidesToAdjust: Edge.Set?)

    /// Convenience method that calculates a frame without requiring an external resize context.
    /// Use this for UI previews, icon generation, and other cases that don't need to track resize state.
    /// - Parameters:
    ///   - action: the window action to calculate the frame for.
    ///   - window: the window to be manipulated (can be nil for UI previews).
    ///   - bounds: the boundary within which the window should be manipulated.
    /// - Returns: the computed frame (raw, without padding).
    static func getFrame(
        for action: WindowAction,
        window: Window?,
        bounds: CGRect,
        padding: PaddingConfiguration? = nil
    ) -> CGRect {
        let context = ResizeContext(window: window, bounds: bounds, padding: padding, action: action)
        return getFrame(resizeContext: context).frame
    }

    /// Returns the frame for the specified window action using the provided resize context.
    /// The returned frame is non-padded. Use `PaddingConfiguration.apply(to:bounds:action:window:)` to apply padding.
    /// - Parameter resizeContext: the context containing window, screen, bounds, and tracking frame/edge adjustment state.
    /// - Returns: a tuple containing the computed frame and the sides to adjust for grow/shrink actions.
    static func getFrame(resizeContext: ResizeContext) -> FrameResult {
        let action = resizeContext.action
        let window = resizeContext.window
        let bounds = resizeContext.paddedBounds
        let direction = action.direction

        let noFrameActions: [WindowDirection] = [.noAction, .noSelection, .cycle, .minimize, .hide]
        guard !noFrameActions.contains(direction), !direction.willFocusWindow else {
            return (CGRect(origin: bounds.center, size: .zero), nil)
        }

        var sidesToAdjust: Edge.Set? = if action.willManipulateExistingWindowFrame {
            resizeContext.sidesToAdjust
        } else {
            nil
        }

        var result: CGRect = calculateTargetFrame(
            for: action,
            window: window,
            bounds: bounds,
            sidesToAdjust: &sidesToAdjust,
            resizeContext: resizeContext
        )

        if result.size.width < 0 || result.size.height < 0 || !result.isFinite {
            result = CGRect(origin: bounds.center, size: .zero)
        }

        return (result, sidesToAdjust)
    }
}

// MARK: - Calculators

extension WindowFrameResolver {
    /// Calculates the target frame for the specified window action based on the direction, window, bounds, and whether it is a preview.
    /// - Parameters:
    ///   - action: the window action to calculate the frame for.
    ///   - window: the window to be manipulated.
    ///   - bounds: the bounds within which the window should be manipulated.
    ///   - sidesToAdjust: inout parameter for tracking which edges to adjust during grow/shrink actions.
    ///   - resizeContext: the context tracking frame and edge adjustment state.
    /// - Returns: the calculated target frame for the specified window action.
    private static func calculateTargetFrame(
        for action: WindowAction,
        window: Window?,
        bounds: CGRect,
        sidesToAdjust: inout Edge.Set?,
        resizeContext: ResizeContext
    ) -> CGRect {
        let direction = action.direction
        var result: CGRect = .zero

        if direction.frameMultiplyValues != nil {
            result = applyFrameMultiplyValues(for: action, to: bounds)

        } else if direction.willAdjustSize {
            // Can't grow or shrink a window that is not resizable
            if let window, !window.isResizable {
                return window.frame
            }

            let frameToResizeFrom = resizeContext.cachedTargetFrame.raw

            // Compute which edges to adjust based on edges touching bounds
            let edgesTouchingBounds = frameToResizeFrom.getEdgesTouchingBounds(bounds)
            sidesToAdjust = .all.subtracting(edgesTouchingBounds)

            let proportional: [WindowDirection] = [.scaleUp, .scaleDown]
            result = calculateSizeAdjustment(
                for: action,
                frameToResizeFrom: frameToResizeFrom,
                bounds: bounds,
                proportionalIfPossible: proportional.contains(direction),
                sidesToAdjust: sidesToAdjust
            )

        } else if direction.willShrink || direction.willGrow {
            // Can't grow or shrink a window that is not resizable
            if let window, !window.isResizable {
                return window.frame
            }

            // This allows for control over each side
            let frameToResizeFrom = resizeContext.cachedTargetFrame.raw

            // Compute which edges to adjust based on direction
            switch direction {
            case .shrinkTop, .growTop:
                sidesToAdjust = .top
            case .shrinkBottom, .growBottom:
                sidesToAdjust = .bottom
            case .shrinkLeft, .growLeft:
                sidesToAdjust = .leading
            case .shrinkHorizontal, .growHorizontal:
                sidesToAdjust = [.leading, .trailing]
            case .shrinkVertical, .growVertical:
                sidesToAdjust = [.top, .bottom]
            default:
                sidesToAdjust = .trailing
            }

            result = calculateSizeAdjustment(
                for: action,
                frameToResizeFrom: frameToResizeFrom,
                bounds: bounds,
                sidesToAdjust: sidesToAdjust
            )

        } else if direction.willMove {
            let frameToResizeFrom = resizeContext.getTargetFrame().raw

            result = calculatePositionAdjustment(for: action, frameToResizeFrom: frameToResizeFrom)

        } else if direction.isCustomizable {
            result = calculateCustomFrame(for: action, window: window, bounds: bounds)

        } else if direction == .center {
            result = calculateCenterFrame(window: window, bounds: bounds)

        } else if direction == .macOSCenter {
            result = calculateMacOSCenterFrame(window: window, bounds: bounds)

        } else if direction == .undo, let window {
            result = getLastActionFrame(window: window, bounds: bounds)

        } else if direction == .initialFrame, let window {
            result = getInitialFrame(window: window)

        } else if direction == .maximizeHeight, let window {
            result = getMaximizeHeightFrame(window: window, bounds: bounds)

        } else if direction == .maximizeWidth, let window {
            result = getMaximizeWidthFrame(window: window, bounds: bounds)

        } else if direction == .unstash, let window {
            result = getInitialFrame(window: window)

        } else if direction == .fillAvailableSpace, let window {
            result = getFillAvailableSpaceFrame(window: window)
        }

        return result
    }

    /// Applies the window direction's frame multiply values to the given bounds.
    /// - Parameters:
    ///   - action: the window action containing the direction with frame multiply values.
    ///   - bounds: the bounds to which the frame multiply values will be applied on.
    /// - Returns: a new `CGRect` with the frame multiply values applied.
    private static func applyFrameMultiplyValues(for action: WindowAction, to bounds: CGRect) -> CGRect {
        guard let frameMultiplyValues = action.direction.frameMultiplyValues else {
            return .zero
        }

        return CGRect(
            x: bounds.origin.x + (bounds.width * frameMultiplyValues.minX),
            y: bounds.origin.y + (bounds.height * frameMultiplyValues.minY),
            width: bounds.width * frameMultiplyValues.width,
            height: bounds.height * frameMultiplyValues.height
        )
    }

    /// Calculates the user-specified custom frame relative to the provided bounds.
    /// - Parameters:
    ///   - action: the window action containing custom frame parameters.
    ///   - window: the window to be manipulated.
    ///   - bounds: the bounds within which the window should be manipulated.
    /// - Returns: the calculated custom frame based on the specified parameters.
    private static func calculateCustomFrame(for action: WindowAction, window: Window?, bounds: CGRect) -> CGRect {
        var result = CGRect(origin: bounds.origin, size: .zero)

        // Size Calculation

        if let sizeMode = action.sizeMode, sizeMode == .preserveSize, let window {
            result.size = window.size

        } else if let sizeMode = action.sizeMode, sizeMode == .initialSize, let window {
            if let initialFrame = WindowRecords.getInitialFrame(for: window) {
                result.size = initialFrame.size
            }

        } else { // sizeMode would be custom
            switch action.unit {
            case .pixels:
                if window == nil {
                    let mainScreen = NSScreen.main ?? NSScreen.screens[0]
                    result.size.width = (CGFloat(action.width ?? .zero) / mainScreen.frame.width) * bounds.width
                    result.size.height = (CGFloat(action.height ?? .zero) / mainScreen.frame.height) * bounds.height
                } else {
                    result.size.width = action.width ?? .zero
                    result.size.height = action.height ?? .zero
                }
            default:
                if let width = action.width {
                    result.size.width = bounds.width * (width / 100.0)
                }

                if let height = action.height {
                    result.size.height = bounds.height * (height / 100.0)
                }
            }
        }

        // Position Calculation

        if let positionMode = action.positionMode, positionMode == .coordinates {
            switch action.unit {
            case .pixels:
                if window == nil {
                    let mainScreen = NSScreen.main ?? NSScreen.screens[0]
                    result.origin.x = (CGFloat(action.xPoint ?? .zero) / mainScreen.frame.width) * bounds.width
                    result.origin.y = (CGFloat(action.yPoint ?? .zero) / mainScreen.frame.height) * bounds.height
                } else {
                    // Note that bounds are ignored deliberately here
                    result.origin.x += action.xPoint ?? .zero
                    result.origin.y += action.yPoint ?? .zero
                }
            default:
                if let xPoint = action.xPoint {
                    result.origin.x += bounds.width * (xPoint / 100.0)
                }

                if let yPoint = action.yPoint {
                    result.origin.y += bounds.height * (yPoint / 100.0)
                }
            }
        } else { // positionMode would be generic
            switch action.anchor {
            case .top:
                result.origin.x = bounds.midX - result.width / 2
            case .topRight:
                result.origin.x = bounds.maxX - result.width
            case .right:
                result.origin.x = bounds.maxX - result.width
                result.origin.y = bounds.midY - result.height / 2
            case .bottomRight:
                result.origin.x = bounds.maxX - result.width
                result.origin.y = bounds.maxY - result.height
            case .bottom:
                result.origin.x = bounds.midX - result.width / 2
                result.origin.y = bounds.maxY - result.height
            case .bottomLeft:
                result.origin.y = bounds.maxY - result.height
            case .left:
                result.origin.y = bounds.midY - result.height / 2
            case .center:
                result.origin.x = bounds.midX - result.width / 2
                result.origin.y = bounds.midY - result.height / 2
            case .macOSCenter:
                let yOffset = getMacOSCenterYOffset(windowHeight: result.height, screenHeight: bounds.height)
                result.origin.x = bounds.midX - result.width / 2
                result.origin.y = (bounds.midY - result.height / 2) + yOffset
            default:
                break
            }
        }

        return result
    }

    /// Calculates the center frame for the window based on the provided bounds. The window's size will not be manipulated if a valid window is passed in.
    /// - Parameters:
    ///   - window: the window to be centered. If `nil`, the center frame will be calculated based on the bounds (and therefore resized)
    ///   - bounds: the bounds within which the window should be centered.
    /// - Returns: the calculated center frame for the window.
    private static func calculateCenterFrame(window: Window?, bounds: CGRect) -> CGRect {
        let windowSize: CGSize = if let window {
            window.size
        } else {
            .init(width: bounds.width / 2, height: bounds.height / 2)
        }

        return CGRect(
            origin: CGPoint(
                x: bounds.midX - (windowSize.width / 2),
                y: bounds.midY - (windowSize.height / 2)
            ),
            size: windowSize
        )
    }

    /// Calculates the "macOS center" frame for the window based on the provided bounds. The window's size will not be manipulated if a valid window is passed in.
    ///
    /// What is a "macOS center"? It is a center frame that is also shifted upwards by a certain amount, determined by the height of the window and the screen height.
    /// Fun fact: this behavior can also be reproduced in your own NSWindows by calling its `center()` method!
    ///
    /// - Parameters:
    ///   - window: the window to be centered. If `nil`, the center frame will be calculated based on the bounds (and therefore resized)
    ///   - bounds: the bounds within which the window should be centered.
    /// - Returns: the calculated "macOS center" frame for the window.
    private static func calculateMacOSCenterFrame(window: Window?, bounds: CGRect) -> CGRect {
        let windowSize: CGSize = if let window {
            window.size
        } else {
            .init(width: bounds.width / 2, height: bounds.height / 2)
        }

        let yOffset = getMacOSCenterYOffset(
            windowHeight: windowSize.height,
            screenHeight: bounds.height
        )

        return CGRect(
            origin: CGPoint(
                x: bounds.midX - (windowSize.width / 2),
                y: bounds.midY - (windowSize.height / 2) + yOffset
            ),
            size: windowSize
        )
    }

    /// This static function is used to calculate the Y offset for a window to be "macOS centered" on the screen
    /// It is identical to `NSWindow.center()`.
    /// - Parameters:
    ///   - windowHeight: Height of the window to be resized
    ///   - screenHeight: Height of the screen the window will be resized on
    /// - Returns: The Y offset of the window, to be added onto the screen's midY point.
    private static func getMacOSCenterYOffset(windowHeight: CGFloat, screenHeight: CGFloat) -> CGFloat {
        let halfScreenHeight = screenHeight / 2
        let windowHeightPercent = windowHeight / screenHeight
        return (0.5 * windowHeightPercent - 0.5) * halfScreenHeight
    }

    /// Retrieves the last action frame for the specified window, based on the last action recorded in `WindowRecords`.
    /// - Parameters:
    ///   - window: the window for which the last action frame is to be retrieved.
    ///   - bounds: the bounds within which the window should be manipulated.
    /// - Returns: the frame of the last action performed on the window, or the current frame if no last action is found.
    private static func getLastActionFrame(window: Window, bounds: CGRect) -> CGRect {
        if let previousAction = WindowRecords.getLastAction(for: window) {
            log.info("Last action was \(previousAction.description)")

            return WindowFrameResolver.getFrame(
                for: previousAction,
                window: window,
                bounds: bounds
            )
        } else {
            log.info("Didn't find frame to undo; using current frame")
            return window.frame
        }
    }

    /// Retrieves the initial frame for the specified window, based on the initial frame recorded in `WindowRecords`.
    /// - Parameter window: the window for which the initial frame is to be retrieved.
    /// - Returns: the initial frame of the window, or the current frame if no initial frame is found.
    private static func getInitialFrame(window: Window) -> CGRect {
        if let initialFrame = WindowRecords.getInitialFrame(for: window) {
            return initialFrame
        } else {
            log.info("Didn't find initial frame; using current frame")
            return window.frame
        }
    }

    /// Computes a new window frame with the maximum height that fits within the given bounds.
    /// - Parameters:
    ///   - window: the window whose current frame is used as a reference.
    ///   - bounds: the area within which the window should be resized.
    /// - Returns: a CGRect representing a frame that maximizes the window's height.
    private static func getMaximizeHeightFrame(window: Window, bounds: CGRect) -> CGRect {
        CGRect(
            x: window.frame.minX,
            y: bounds.minY,
            width: window.frame.width,
            height: bounds.height
        )
    }

    /// Computes a new window frame with the maximum width that fits within the given bounds.
    /// - Parameters:
    ///   - window: the window whose current frame is used as a reference.
    ///   - bounds: the area within which the window should be resized.
    /// - Returns: a CGRect representing a frame that maximizes the window's width.
    private static func getMaximizeWidthFrame(window: Window, bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.minX,
            y: window.frame.minY,
            width: bounds.width,
            height: window.frame.height
        )
    }

    /// Computes a new window frame that takes up the most area, without overlapping with other windows.
    /// Other windows that already overlap with the current window will be ignored.
    /// - Parameter window: the window whose current frame is used as a reference.
    /// - Returns: a CGRect representing a frame that makes a window fill the most available space.
    private static func getFillAvailableSpaceFrame(window: Window) -> CGRect {
        let currentFrame = window.frame

        guard let screen = ScreenUtility.screenContaining(window) ?? NSScreen.main else { return currentFrame }
        let screenFrame = screen.cgSafeScreenFrame

        let nonIntersectingWindowFrames = WindowUtility.windowList()
            .map(\.frame)
            .filter { !$0.intersects(currentFrame) } // Ensure it doesn't intersect with the current window
            .map { $0.intersection(screenFrame) } // Crop it to the screen frame

        /// Computes the closest window obstacle in each of the four cardinal directions
        /// (left, right, top, bottom) relative to the current window, and returns the boundaries
        /// formed by these obstacles, constrained to the screen frame.
        func computeBoundaries() -> (minX: CGFloat, minY: CGFloat, maxX: CGFloat, maxY: CGFloat) {
            var minX = screenFrame.minX
            var minY = screenFrame.minY
            var maxX = screenFrame.maxX
            var maxY = screenFrame.maxY

            for frame in nonIntersectingWindowFrames {
                if frame.maxX <= currentFrame.minX { minX = max(minX, frame.maxX) }
                if frame.maxY <= currentFrame.minY { minY = max(minY, frame.maxY) }
                if frame.minX >= currentFrame.maxX { maxX = min(maxX, frame.minX) }
                if frame.minY >= currentFrame.maxY { maxY = min(maxY, frame.minY) }
            }

            return (minX, minY, maxX, maxY)
        }

        let (minX, minY, maxX, maxY) = computeBoundaries()

        // Needed for Hashable conformance
        struct Boundary: Hashable {
            let min: CGFloat
            let max: CGFloat
        }

        let uniqueXBoundaries: Set<Boundary> = [
            Boundary(min: minX, max: maxX), // Respect obstacles in both directions
            Boundary(min: currentFrame.minX, max: maxX), // Keep left, expand right
            Boundary(min: minX, max: currentFrame.maxX), // Expand left, keep right
            Boundary(min: currentFrame.minX, max: screenFrame.maxX), // Keep left, expand right to screen edge
            Boundary(min: screenFrame.minX, max: currentFrame.maxX), // Expand left to screen edge, keep right
            Boundary(min: screenFrame.minX, max: screenFrame.maxX) // Full screen width
        ]

        let uniqueYBoundaries: Set<Boundary> = [
            Boundary(min: minY, max: maxY), // Respect obstacles in both directions
            Boundary(min: currentFrame.minY, max: maxY), // Keep bottom, expand top
            Boundary(min: minY, max: currentFrame.maxY), // Expand bottom, keep top
            Boundary(min: currentFrame.minY, max: screenFrame.maxY), // Keep bottom, expand top to screen edge
            Boundary(min: screenFrame.minY, max: currentFrame.maxY), // Expand bottom to screen edge, keep top
            Boundary(min: screenFrame.minY, max: screenFrame.maxY) // Full screen height
        ]

        // Generate all possible combinations of x/y boundaries and filter it to valid candidates.
        // A candidate is valid if it doesn't overlap with any other window.
        let validCandidates = uniqueXBoundaries.flatMap { xBound in
            uniqueYBoundaries.compactMap { yBound in
                let combination = CGRect(
                    x: xBound.min,
                    y: yBound.min,
                    width: xBound.max - xBound.min,
                    height: yBound.max - yBound.min
                )

                return nonIntersectingWindowFrames.allSatisfy { !$0.intersects(combination) } ? combination : nil
            }
        }

        return validCandidates.max { $0.size.area < $1.size.area } ?? currentFrame
    }

    /// Calculates the size adjustment for the specified frame based on the bounds and the direction of the action.
    /// - Parameters:
    ///   - action: the window action containing the direction.
    ///   - frameToResizeFrom: the frame to apply the size adjustment to.
    ///   - bounds: the bounds within which the frame should be resized.
    ///   - proportionalIfPossible: if true and all edges are resized, scales proportionally about the center instead of insetting each side.
    ///   - sidesToAdjust: which edges to adjust during the resize.
    /// - Returns: the adjusted frame after applying the size adjustment based on the direction and bounds.
    private static func calculateSizeAdjustment(
        for action: WindowAction,
        frameToResizeFrom: CGRect,
        bounds: CGRect,
        proportionalIfPossible: Bool = false,
        sidesToAdjust: Edge.Set?
    ) -> CGRect {
        let direction = action.direction
        let step = Defaults[.sizeIncrement] * ((direction == .larger || direction == .scaleUp || direction.willGrow) ? -1 : 1)

        let previewPadding = Defaults[.previewPadding]
        let minSize = CGSize(
            width: previewPadding + 100,
            height: previewPadding + 100
        )

        func insetAllEdges(_ rect: CGRect) -> CGRect {
            rect.inset(by: step, minSize: minSize)
        }

        func scaleAllEdgesIfPossible(_ rect: CGRect) -> CGRect? {
            guard proportionalIfPossible, rect.width > 0, rect.height > 0 else { return nil }

            let sx = (rect.width - 2 * step) / rect.width
            let sy = (rect.height - 2 * step) / rect.height
            var targetUniformScale = min(sx, sy)

            guard targetUniformScale.isFinite, targetUniformScale > 0 else { return nil }
            let minScaleToSatisfyMinWidth = minSize.width / rect.width
            let minScaleToSatisfyMinHeight = minSize.height / rect.height
            let minUniformScale = max(minScaleToSatisfyMinWidth, minScaleToSatisfyMinHeight)
            targetUniformScale = max(targetUniformScale, minUniformScale)

            let rectCenter = CGPoint(
                x: rect.midX,
                y: rect.midY
            )

            let scaledSize = CGSize(
                width: rect.width * targetUniformScale,
                height: rect.height * targetUniformScale
            )

            let scaledRect = CGRect(
                x: rectCenter.x - scaledSize.width / 2,
                y: rectCenter.y - scaledSize.height / 2,
                width: scaledSize.width,
                height: scaledSize.height
            )

            return scaledRect
        }

        var result = frameToResizeFrom

        if let edges = sidesToAdjust {
            let resizeAllEdges = edges.isEmpty || edges.contains(.all)

            if resizeAllEdges {
                result = scaleAllEdgesIfPossible(result) ?? insetAllEdges(result)
            } else {
                result = result.padding(edges, step)

                if result.width < minSize.width {
                    result.size.width = minSize.width
                    result.origin.x = frameToResizeFrom.midX - minSize.width / 2
                }
                if result.height < minSize.height {
                    result.size.height = minSize.height
                    result.origin.y = frameToResizeFrom.midY - minSize.height / 2
                }
            }
        }

        result = result
            .intersection(bounds)

        if result.size.approximatelyEqual(to: frameToResizeFrom.size, tolerance: 2) {
            result = frameToResizeFrom
        }

        return result
    }

    /// Calculates the position adjustment for the specified frame based on the direction of the action.
    /// - Parameters:
    ///   - action: the window action containing the direction.
    ///   - frameToResizeFrom: the frame to apply the position adjustment to.
    /// - Returns: the adjusted frame after applying the position adjustment based on the direction.
    private static func calculatePositionAdjustment(for action: WindowAction, frameToResizeFrom: CGRect) -> CGRect {
        let direction = action.direction
        var result = frameToResizeFrom

        if direction == .moveUp {
            result.origin.y -= Defaults[.sizeIncrement]
        } else if direction == .moveDown {
            result.origin.y += Defaults[.sizeIncrement]
        } else if direction == .moveRight {
            result.origin.x += Defaults[.sizeIncrement]
        } else if direction == .moveLeft {
            result.origin.x -= Defaults[.sizeIncrement]
        }

        return result
    }
}
