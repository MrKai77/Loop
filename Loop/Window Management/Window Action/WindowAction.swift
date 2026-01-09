//
//  WindowAction.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-28.
//

import Defaults
import Scribe
import SwiftUI

/// The window action struct represents a single action that can be performed on a window, such as resizing, moving, or cycling through actions.
///
/// Common actions, such as right half, or bottom right quarter, are represented by `WindowDirection` enum, while user-made actions, such as custom frames and cycles are speciied by this struct.
struct WindowAction: Codable, Identifiable, Hashable, Equatable, Defaults.Serializable {
    private(set) var id: UUID
    private static var sharedNoSelectionId: UUID = .init()

    /// Initializes a `WindowAction` with the specified parameters. Only to be used when decoding from JSON.
    /// - Parameters:
    ///   - direction: the direction of the window action. If custom or cycle, use those and further specify the action with the parameters below.
    ///   - keybind: the keybinds associated with this action. If empty, the action is not bound to any key.
    ///   - name: the name of the action. If `nil`, the name will be derived from the direction.
    ///   - unit: the unit of measurement for width and height.  This needs to be specified for custom actions.
    ///   - anchor: the anchor point for the action.  This needs to be specified for custom actions that use a `generic` ``positionMode``
    ///   - width: the width of the window. This needs to be specified for custom actions.
    ///   - height: the height of the window. This needs to be specified for custom actions.
    ///   - xPoint: the x-coordinate of the window's position. This needs to be specified for custom actions with a `coordinates` ``positionMode``.
    ///   - yPoint: the y-coordinate of the window's position. This needs to be specified for custom actions with a `coordinates` ``positionMode``.
    ///   - positionMode: whether to use anchors or exact coordinates to move a window. This needs to be specified for custom actions.
    ///   - sizeMode: the size mode of the action, which allows users to preserve size when manipulating a window.
    ///   - cycle: The cycling window actions.
    init(
        _ direction: WindowDirection,
        keybind: Set<CGKeyCode>,
        name: String? = nil,
        unit: CustomWindowActionUnit? = nil,
        anchor: CustomWindowActionAnchor? = nil,
        width: Double? = nil,
        height: Double? = nil,
        xPoint: Double? = nil,
        yPoint: Double? = nil,
        positionMode: CustomWindowActionPositionMode? = nil,
        sizeMode: CustomWindowActionSizeMode? = nil,
        cycle: [WindowAction]? = nil
    ) {
        self.id = UUID()
        self.direction = direction
        self.keybind = keybind
        self.name = name
        self.unit = unit
        self.anchor = anchor
        self.width = width
        self.height = height
        self.positionMode = positionMode
        self.xPoint = xPoint
        self.yPoint = yPoint
        self.sizeMode = sizeMode
        self.cycle = cycle
    }

    /// Initializes a `WindowAction` with the specified direction and an empty keybind.
    /// - Parameter direction: the direction of the window action.
    init(_ direction: WindowDirection, keybind: Set<CGKeyCode> = []) {
        if direction == .noSelection {
            self.id = Self.sharedNoSelectionId
        } else {
            self.id = UUID()
        }

        self.direction = direction
        self.keybind = keybind
    }

    /// Initializes a cycle `WindowAction`. Used for user-defined cycles.
    /// - Parameters:
    ///   - name: the name of the cycle. If `nil`, a default name will be used (eg. "Custom Cycle").
    ///   - cycle: the cycle of window actions. This is an array of `WindowAction` that will be cycled through when the action is triggered.
    ///   - keybind: the keybinds associated with this action.
    init(_ name: String? = nil, cycle: [WindowAction], keybind: Set<CGKeyCode> = []) {
        self.id = UUID()
        self.direction = .cycle
        self.name = name
        self.cycle = cycle
        self.keybind = keybind
    }

    /// Initializes a cycle without a name or keybind. Used in radial menu.
    /// - Parameter cycle: the cycle of window actions.
    init(_ cycle: [WindowAction]) {
        self.init(nil, cycle: cycle)
    }

    // Generic Properties
    var direction: WindowDirection
    var keybind: Set<CGKeyCode>

    // Custom Keybind Properties
    var name: String?
    var unit: CustomWindowActionUnit?
    var anchor: CustomWindowActionAnchor?
    var sizeMode: CustomWindowActionSizeMode?
    var width: Double?
    var height: Double?
    var positionMode: CustomWindowActionPositionMode?
    var xPoint: Double?
    var yPoint: Double?

    // Custom Cycle Properties
    var cycle: [WindowAction]?

    // MARK: - Methods

    /// Retrieves the name of the action, either from the `name` property or from the `direction` enum.
    /// - Returns: the name of the action.
    func getName() -> String {
        var result = ""

        if direction == .custom {
            result = if let name, !name.isEmpty {
                name
            } else {
                .init(localized: .init("Custom Action", defaultValue: "Custom Action"))
            }
        } else if direction == .stash {
            result = if let name, !name.isEmpty {
                name
            } else {
                .init(localized: .init("Stash", defaultValue: "Stash"))
            }
        } else if direction == .cycle {
            result = if let name, !name.isEmpty {
                name
            } else {
                .init(localized: .init("Custom Cycle", defaultValue: "Custom Cycle"))
            }
        } else {
            result = direction.name
        }

        return result
    }

    /// Determines if the action will manipulate the existing window frame, rather than setting an entirely new frame from scratch.
    var willManipulateExistingWindowFrame: Bool {
        if direction.willAdjustSize ||
            direction.willShrink ||
            direction.willGrow ||
            direction.willMove {
            return true
        }

        return false
    }

    var canRepeat: Bool {
        willManipulateExistingWindowFrame || direction.willFocusWindow || direction == .undo
    }

    var forceProportionalFrameOnScreenChange: Bool {
        direction.willCenter || willManipulateExistingWindowFrame
    }

    /// Determines if padding can be applied to the action.
    var isPaddingApplicable: Bool {
        if direction == .undo || direction == .initialFrame {
            return false
        }

        if direction.isCustomizable, sizeMode == .initialSize || sizeMode == .preserveSize {
            return false
        }

        return true
    }

    var eligibleForReverseCycle: Bool {
        direction == .cycle && !keybind.contains(.kVK_Shift)
    }

    /// Determines the angle to show in the radial menu, if applicable.
    /// Examples of actions where the radial menu angle is not applicable:
    /// - No action (noAction)
    /// - Hiding the window (hide)
    /// - Minimizing the window (minimize)
    /// - Cycling through actions (cycle) - the selected action's angle will be used instead within the radial menu's selected action logic.
    ///
    /// - Parameter window: the window to be manipulated. If `nil`, the angle will be calculated based on the screen center.
    /// - Returns: the angle to show in the radial menu, or `nil` if the action does not have a radial menu angle.
    func radialMenuAngle(window: Window?) -> Angle? {
        guard
            direction.frameMultiplyValues != nil,
            direction.hasRadialMenuAngle
        else {
            return nil
        }

        let frame = CGRect(origin: .zero, size: .init(width: 1, height: 1))
        let targetWindowFrame = getFrame(window: window, bounds: frame, disablePadding: true)
        let angle = frame.center.angle(to: targetWindowFrame.center)
        let result: Angle = angle * -1

        return result.normalized()
    }

    /// Returns the frame for the specified window action within a given boundary.
    /// - Parameters:
    ///   - window: the window to be manipulated.
    ///   - bounds: the boundary within which the window should be manipulated.
    ///   - disablePadding: whether to disable padding. `true` when calculating non-AX-usage frames, such as for angle calculations in radial menu or in config UI.
    ///   - screen: the screen on which the bounds are located. Only used to determine if padding should be applied (see `getBounds()`).
    ///   - isPreview: ensures that when manipulating the preview window, the last target frame does not affect the actual resizing of the window.
    /// - Returns: the calculated frame for the specified window action.
    func getFrame(
        window: Window?,
        bounds: CGRect,
        disablePadding: Bool = false,
        screen: NSScreen? = nil,
        isPreview: Bool = false
    ) -> CGRect {
        let noFrameActions: [WindowDirection] = [.noAction, .noSelection, .cycle, .minimize, .hide]
        guard !noFrameActions.contains(direction), !direction.willFocusWindow else {
            return NSRect(origin: bounds.center, size: .zero)
        }

        if !willManipulateExistingWindowFrame {
            LoopManager.sidesToAdjust = nil
        }

        let padding = disablePadding ? .zero : PaddingSettings.configuredPadding(for: screen)
        var bounds = padding.apply(onScreenFrame: bounds)
        var result: CGRect = calculateTargetFrame(
            direction: direction,
            window: window,
            bounds: bounds,
            padding: padding,
            isPreview: isPreview
        )

        if !disablePadding {
            if !willManipulateExistingWindowFrame {
                /// Convert rects to integers as that's what the AX API works with to move windows
                /// Only do this when `!willManipulateExistingWindowFrame`, as otherwise, the window will drift with consecutive calls.
                bounds = bounds.integerRect()
                result = result.integerRect()
            }

            // If window can't be resized, center it within the already-resized frame.
            if let window, window.isResizable == false {
                result = window.frame.size
                    .center(inside: result)
                    .pushInside(bounds)
            } else {
                // Apply padding between windows
                if isPaddingApplicable {
                    result = applyInnerPadding(
                        windowFrame: result,
                        bounds: bounds,
                        screen: screen
                    )
                }
            }

            // Store the last target frame. This is used when growing/shrinking windows
            // We only store it when disablePadding is false, as otherwise, it is going to be the preview window using this frame.
            LoopManager.lastTargetFrame = result
        }

        if result.size.width < 0 || result.size.height < 0 || !result.isFinite {
            result = CGRect(origin: bounds.center, size: .zero)
        }

        return result
    }
}

// MARK: - Window Frame Calculations

extension WindowAction {
    /// Calculates the target frame for the specified window action based on the direction, window, bounds, and whether it is a preview.
    /// - Parameters:
    ///   - direction: the direction of the window action.
    ///   - window: the window to be manipulated.
    ///   - bounds: the bounds within which the window should be manipulated.
    ///   - padding: the padding which will be applied to the computed frame.
    ///   - isPreview: whether the action is being performed on a preview window.
    /// - Returns: the calculated target frame for the specified window action.
    private func calculateTargetFrame(
        direction: WindowDirection,
        window: Window?,
        bounds: CGRect,
        padding: PaddingModel,
        isPreview: Bool
    ) -> CGRect {
        var result: CGRect = .zero

        if direction.frameMultiplyValues != nil {
            result = applyFrameMultiplyValues(to: bounds)

        } else if direction.willAdjustSize {
            // Can't grow or shrink a window that is not resizable
            if let window, !window.isResizable {
                return window.frame
            }

            // Return final frame of preview
            if Defaults[.previewVisibility], !isPreview {
                return LoopManager.lastTargetFrame
            }

            let frameToResizeFrom = LoopManager.lastTargetFrame

            // calculateSizeAdjustment() will read LoopManager.sidesToAdjust, but we compute them here
            let edgesTouchingBounds = frameToResizeFrom.getEdgesTouchingBounds(bounds)
            LoopManager.sidesToAdjust = .all.subtracting(edgesTouchingBounds)

            let proportional: [WindowDirection] = [.scaleUp, .scaleDown]
            result = calculateSizeAdjustment(
                frameToResizeFrom: frameToResizeFrom,
                bounds: bounds,
                proportionalIfPossible: proportional.contains(direction),
                padding: padding
            )

        } else if direction.willShrink || direction.willGrow {
            // Can't grow or shrink a window that is not resizable
            if let window, !window.isResizable {
                return window.frame
            }

            // Return final frame of preview
            if Defaults[.previewVisibility], !isPreview {
                return LoopManager.lastTargetFrame
            }

            // This allows for control over each side
            let frameToResizeFrom = LoopManager.lastTargetFrame

            // calculateSizeAdjustment() will read LoopManager.sidesToAdjust, but we compute them here
            switch direction {
            case .shrinkTop, .growTop:
                LoopManager.sidesToAdjust = .top
            case .shrinkBottom, .growBottom:
                LoopManager.sidesToAdjust = .bottom
            case .shrinkLeft, .growLeft:
                LoopManager.sidesToAdjust = .leading
            case .shrinkHorizontal, .growHorizontal:
                LoopManager.sidesToAdjust = [.leading, .trailing]
            case .shrinkVertical, .growVertical:
                LoopManager.sidesToAdjust = [.top, .bottom]
            default:
                LoopManager.sidesToAdjust = .trailing
            }

            result = calculateSizeAdjustment(
                frameToResizeFrom: frameToResizeFrom,
                bounds: bounds,
                padding: padding
            )

        } else if direction.willMove {
            // Return final frame of preview
            if Defaults[.previewVisibility], !isPreview {
                return LoopManager.lastTargetFrame
            }

            let frameToResizeFrom = LoopManager.lastTargetFrame

            result = calculatePositionAdjustment(frameToResizeFrom: frameToResizeFrom)

        } else if direction.isCustomizable {
            result = calculateCustomFrame(window: window, bounds: bounds)

        } else if direction == .center {
            result = calculateCenterFrame(window: window, bounds: bounds)

        } else if direction == .macOSCenter {
            result = calculateMacOSCenterFrame(window: window, bounds: bounds)

        } else if direction == .undo, let window {
            result = getLastActionFrame(window: window, bounds: bounds)

        } else if direction == .initialFrame, let window {
            result = getInitialFrame(window: window)

        } else if direction == .maximizeHeight, let window {
            result = getMaximizeHeightFrame(window: window, bounds: bounds, padding: padding)

        } else if direction == .maximizeWidth, let window {
            result = getMaximizeWidthFrame(window: window, bounds: bounds, padding: padding)

        } else if direction == .unstash, let window {
            result = getInitialFrame(window: window)

        } else if direction == .fillAvailableSpace, let window {
            result = getFillAvailableSpaceFrame(window: window)
        }

        return result
    }

    /// Applies the window direction's frame multiply values to the given bounds.
    /// - Parameter bounds: the bounds to which the frame multiply values will be applied on.
    /// - Returns: a new `CGRect` with the frame multiply values applied.
    private func applyFrameMultiplyValues(to bounds: CGRect) -> CGRect {
        guard let frameMultiplyValues = direction.frameMultiplyValues else {
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
    ///   - window: the window to be manipulated.
    ///   - bounds: the bounds within which the window should be manipulated.
    /// - Returns: the calculated custom frame based on the specified parameters.
    private func calculateCustomFrame(window: Window?, bounds: CGRect) -> CGRect {
        var result = CGRect(origin: bounds.origin, size: .zero)

        // Size Calculation

        if let sizeMode, sizeMode == .preserveSize, let window {
            result.size = window.size

        } else if let sizeMode, sizeMode == .initialSize, let window {
            if let initialFrame = WindowRecords.getInitialFrame(for: window) {
                result.size = initialFrame.size
            }

        } else { // sizeMode would be custom
            switch unit {
            case .pixels:
                if window == nil {
                    let mainScreen = NSScreen.main ?? NSScreen.screens[0]
                    result.size.width = (CGFloat(width ?? .zero) / mainScreen.frame.width) * bounds.width
                    result.size.height = (CGFloat(height ?? .zero) / mainScreen.frame.height) * bounds.height
                } else {
                    result.size.width = width ?? .zero
                    result.size.height = height ?? .zero
                }
            default:
                if let width {
                    result.size.width = bounds.width * (width / 100.0)
                }

                if let height {
                    result.size.height = bounds.height * (height / 100.0)
                }
            }
        }

        // Position Calculation

        if let positionMode, positionMode == .coordinates {
            switch unit {
            case .pixels:
                if window == nil {
                    let mainScreen = NSScreen.main ?? NSScreen.screens[0]
                    result.origin.x = (CGFloat(xPoint ?? .zero) / mainScreen.frame.width) * bounds.width
                    result.origin.y = (CGFloat(yPoint ?? .zero) / mainScreen.frame.height) * bounds.height
                } else {
                    // Note that bounds are ignored deliberately here
                    result.origin.x += xPoint ?? .zero
                    result.origin.y += yPoint ?? .zero
                }
            default:
                if let xPoint {
                    result.origin.x += bounds.width * (xPoint / 100.0)
                }

                if let yPoint {
                    result.origin.y += bounds.height * (yPoint / 100.0)
                }
            }
        } else { // positionMode would be generic
            switch anchor {
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
    private func calculateCenterFrame(window: Window?, bounds: CGRect) -> CGRect {
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
    private func calculateMacOSCenterFrame(window: Window?, bounds: CGRect) -> CGRect {
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

    /// This function is used to calculate the Y offset for a window to be "macOS centered" on the screen
    /// It is identical to `NSWindow.center()`.
    /// - Parameters:
    ///   - windowHeight: Height of the window to be resized
    ///   - screenHeight: Height of the screen the window will be resized on
    /// - Returns: The Y offset of the window, to be added onto the screen's midY point.
    private func getMacOSCenterYOffset(windowHeight: CGFloat, screenHeight: CGFloat) -> CGFloat {
        let halfScreenHeight = screenHeight / 2
        let windowHeightPercent = windowHeight / screenHeight
        return (0.5 * windowHeightPercent - 0.5) * halfScreenHeight
    }

    /// Retrieves the last action frame for the specified window, based on the last action recorded in `WindowRecords`.
    /// - Parameters:
    ///   - window: the window for which the last action frame is to be retrieved.
    ///   - bounds: the bounds within which the window should be manipulated.
    /// - Returns: the frame of the last action performed on the window, or the current frame if no last action is found.
    private func getLastActionFrame(window: Window, bounds: CGRect) -> CGRect {
        if let previousAction = WindowRecords.getLastAction(for: window) {
            Log.info("Last action was \(previousAction.description)", category: .windowAction)

            return previousAction.getFrame(
                window: window,
                bounds: bounds,
                disablePadding: true
            )
        } else {
            Log.info("Didn't find frame to undo; using current frame", category: .windowAction)
            return window.frame
        }
    }

    /// Retrieves the initial frame for the specified window, based on the initial frame recorded in `WindowRecords`.
    /// - Parameter window: the window for which the initial frame is to be retrieved.
    /// - Returns: the initial frame of the window, or the current frame if no initial frame is found.
    private func getInitialFrame(window: Window) -> CGRect {
        if let initialFrame = WindowRecords.getInitialFrame(for: window) {
            return initialFrame
        } else {
            Log.info("Didn't find initial frame; using current frame", category: .windowAction)
            return window.frame
        }
    }

    /// Computes a new window frame with the maximum height that fits within the given bounds.
    /// The provided padding is factored in to account for later adjustments.
    /// - Parameters:
    ///   - window: the window whose current frame is used as a reference.
    ///   - bounds: the area within which the window should be resized.
    ///   - padding: the padding to be applied to the window.
    /// - Returns: a CGRect representing a frame that maximizes the window's height.
    private func getMaximizeHeightFrame(window: Window, bounds: CGRect, padding: PaddingModel) -> CGRect {
        CGRect(
            x: window.frame.minX - padding.window / 2,
            y: bounds.minY,
            width: window.frame.width + padding.window,
            height: bounds.height
        )
    }

    /// Computes a new window frame with the maximum width that fits within the given bounds.
    /// The provided padding is factored in to account for later adjustments.
    /// - Parameters:
    ///   - window: the window whose current frame is used as a reference.
    ///   - bounds: the area within which the window should be resized.
    ///   - padding: the padding to be applied to the window.
    /// - Returns: a CGRect representing a frame that maximizes the window's width.
    private func getMaximizeWidthFrame(window: Window, bounds: CGRect, padding: PaddingModel) -> CGRect {
        CGRect(
            x: bounds.minX,
            y: window.frame.minY - padding.window / 2,
            width: bounds.width,
            height: window.frame.height + padding.window
        )
    }

    /// Computes a new window frame that takes up the most area, without overlapping with other windows.
    /// Other windows that already overlap with the current window will be ignored.
    /// - Parameter window: the window whose current frame is used as a reference.
    /// - Returns: a CGRect representing a frame that makes a window fill the most available space.
    private func getFillAvailableSpaceFrame(window: Window) -> CGRect {
        let currentFrame = window.frame

        guard let screen = ScreenUtility.screenContaining(window) ?? NSScreen.main else { return currentFrame }
        let screenFrame = screen.safeScreenFrame

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
    ///   - frameToResizeFrom: the frame to apply the size adjustment to.
    ///   - bounds: the bounds within which the frame should be resized.
    ///   - proportionalIfPossible: if true and all edges are resized, scales proportionally about the center instead of insetting each side.
    /// - Returns: the adjusted frame after applying the size adjustment based on the direction and bounds.
    private func calculateSizeAdjustment(
        frameToResizeFrom: CGRect,
        bounds: CGRect,
        proportionalIfPossible: Bool = false,
        padding: PaddingModel
    ) -> CGRect {
        let step = Defaults[.sizeIncrement] * ((direction == .larger || direction == .scaleUp || direction.willGrow) ? -1 : 1)

        let previewPadding = Defaults[.previewPadding]
        let minSize = CGSize(
            width: padding.left + padding.right + previewPadding + 100,
            height: padding.totalTopPadding + padding.bottom + previewPadding + 100
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

        if let edges = LoopManager.sidesToAdjust {
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

        if result.size.approximatelyEqual(to: LoopManager.lastTargetFrame.size, tolerance: 2) {
            result = LoopManager.lastTargetFrame
        }

        return result
    }

    /// Calculates the position adjustment for the specified frame based on the direction of the action.
    /// - Parameter frameToResizeFrom: the frame to apply the position adjustment to.
    /// - Returns: the adjusted frame after applying the position adjustment based on the direction.
    private func calculatePositionAdjustment(frameToResizeFrom: CGRect) -> CGRect {
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

    /// Applies inner padding to the specified window frame based on the direction and bounds.
    /// "Inner padding" is the padding applied to the sides of the window frame, which aren't touching the side of the screen.
    /// - Parameters:
    ///   - windowFrame: the frame of the window to which padding will be applied.
    ///   - bounds: the bounds within which the window should be padded.
    ///   - screen: the screen on which the bounds are located. This is used to determine if padding should be applied based on the screen size (if applicable).
    /// - Returns: the window frame with the specified padding applied.
    private func applyInnerPadding(windowFrame: CGRect, bounds: CGRect, screen: NSScreen?) -> CGRect {
        guard !direction.willMove else {
            return windowFrame
        }

        var croppedWindowFrame = windowFrame.intersection(bounds)

        let paddingMinimumScreenSize = Defaults[.paddingMinimumScreenSize]
        if paddingMinimumScreenSize != .zero,
           screen?.diagonalSize ?? .zero < paddingMinimumScreenSize {
            return windowFrame
        }

        guard
            !willManipulateExistingWindowFrame,
            Defaults[.enablePadding]
        else {
            return croppedWindowFrame
        }

        let padding = PaddingSettings.configuredPadding(for: screen)
        let halfPadding = padding.window / 2

        if direction == .macOSCenter,
           windowFrame.height >= bounds.height {
            croppedWindowFrame.origin.y = bounds.minY
            croppedWindowFrame.size.height = bounds.height
        }

        if direction == .center || direction == .macOSCenter {
            return croppedWindowFrame
        }

        if abs(croppedWindowFrame.minX - bounds.minX) > 1 {
            croppedWindowFrame = croppedWindowFrame.padding(.leading, halfPadding)
        }

        if abs(croppedWindowFrame.maxX - bounds.maxX) > 1 {
            croppedWindowFrame = croppedWindowFrame.padding(.trailing, halfPadding)
        }

        if abs(croppedWindowFrame.minY - bounds.minY) > 1 {
            croppedWindowFrame = croppedWindowFrame.padding(.top, halfPadding)
        }

        if abs(croppedWindowFrame.maxY - bounds.maxY) > 1 {
            croppedWindowFrame = croppedWindowFrame.padding(.bottom, halfPadding)
        }

        return croppedWindowFrame
    }
}

extension WindowAction: CustomStringConvertible {
    var description: String {
        "WindowAction(direction: \(direction), name: \(getName()))"
    }
}
