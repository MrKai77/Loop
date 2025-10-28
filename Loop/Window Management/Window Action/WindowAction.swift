//
//  WindowAction.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-28.
//

import Defaults
import OSLog
import SwiftUI

/// The window action struct represents a single action that can be performed on a window, such as resizing, moving, or cycling through actions.
///
/// Common actions, such as right half, or bottom right quarter, are represented by `WindowDirection` enum, while user-made actions, such as custom frames and cycles are speciied by this struct.
struct WindowAction: Codable, Identifiable, Hashable, Equatable, Defaults.Serializable {
    private static let logger = Logger(category: "WindowAction")

    var id: UUID = .init()

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
        self.direction = direction
        self.keybind = keybind
    }

    /// Initializes a cycle `WindowAction`. Used for user-defined cycles.
    /// - Parameters:
    ///   - name: the name of the cycle. If `nil`, a default name will be used (eg. "Custom Cycle").
    ///   - cycle: the cycle of window actions. This is an array of `WindowAction` that will be cycled through when the action is triggered.
    ///   - keybind: the keybinds associated with this action.
    init(_ name: String? = nil, cycle: [WindowAction], keybind: Set<CGKeyCode> = []) {
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

    /// Determines if one action is equivalent to another, ignore all properties that are not related to resizing or moving the window.
    /// - Parameter other: the other `WindowAction` to compare against.
    /// - Returns: `true` if the two actions are equivalent in terms of resizing or moving the window, otherwise `false`.
    func isSameManipulation(as other: WindowAction) -> Bool {
        let commonID = UUID()

        /// Removes ID, keybind and name. This is useful when checking for equality between an otherwise identical keybind and radial menu action.
        func stripNonResizingProperties(of action: WindowAction) -> WindowAction {
            var strippedAction = action
            strippedAction.id = commonID
            strippedAction.keybind = []
            strippedAction.name = nil

            if let cycle = action.cycle {
                strippedAction.cycle = cycle.map { stripNonResizingProperties(of: $0) }
            }

            return strippedAction
        }

        let modifiedSelf = stripNonResizingProperties(of: self)
        let modifiedOther = stripNonResizingProperties(of: other)

        return modifiedSelf == modifiedOther
    }

    /// Retrieves the name of the action, either from the `name` property or from the `direction` enum.
    /// - Returns: the name of the action.
    func getName() -> String {
        var result = ""

        if direction == .custom {
            result = if let name, !name.isEmpty {
                name
            } else {
                .init(localized: .init("Custom Keybind", defaultValue: "Custom Keybind"))
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
        let result: Angle = .radians(angle) * -1

        return result.normalized()
    }

    /// Returns the frame for the specified window action within a given boundary.
    /// - Parameters:
    ///   - window: the window to be manipulated.
    ///   - bounds: the boundary within which the window should be manipulated.
    ///   - disablePadding: whether to disable padding. `true` when calculating non-AX-usage frames, such as for angle calculations in radial menu or in config UI.
    ///   - screen: the screen on which the bounds are located. Only used to determine if padding should be applied (see `getBounds()`).
    ///   - isPreview: ensures that when manipulating the preview window, the last target frame does not affect the actual resizing of the window.
    ///   - proportionalFrame: optional proportional frame when moving between screens. Values should be between 0.0 and 1.0.
    /// - Returns: the calculated frame for the specified window action.
    func getFrame(window: Window?, bounds: CGRect, disablePadding: Bool = false, screen: NSScreen? = nil, isPreview: Bool = false, proportionalFrame: CGRect? = nil) -> CGRect {
        let noFrameActions: [WindowDirection] = [.noAction, .cycle, .minimize, .hide]
        guard !noFrameActions.contains(direction) else {
            return NSRect(origin: bounds.center, size: .zero)
        }

        if !willManipulateExistingWindowFrame {
            LoopManager.sidesToAdjust = nil
        }

        var bounds: CGRect = getBounds(from: bounds, disablePadding: disablePadding, screen: screen)
        var result: CGRect = calculateTargetFrame(direction, window, bounds, isPreview, proportionalFrame: proportionalFrame)

        if !disablePadding {
            if !willManipulateExistingWindowFrame {
                // Convert rects to integers as that's what the AX API works with to move windows
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
                    result = applyInnerPadding(result, bounds)
                }
            }

            // Store the last target frame. This is used when growing/shrinking windows
            // We only store it when disablePadding is false, as otherwise, it is going to be the preview window using this frame.
            LoopManager.lastTargetFrame = result
        }

        if result.size.width < 0 || result.size.height < 0 {
            result = CGRect(origin: bounds.center, size: .zero)
        }

        return result
    }
}

// MARK: - Window Frame Calculations

extension WindowAction {
    /// Retrieves the bounds for the action based on: the original bounds, whether padding should be applied, and the screen size.
    /// - Parameters:
    ///   - originalBounds: the bounds of the screen/frame to resize on.
    ///   - disablePadding: whether to disable padding. If `true`, the bounds will not be padded. This is useful when calculating frames for the radial menu.
    ///   - screen: the screen on which the bounds are located. This is used to determine if padding should be applied based on the screen size (if applicable).
    /// - Returns: the padded bounds if padding can be applied, otherwise the original bounds.
    private func getBounds(from originalBounds: CGRect, disablePadding: Bool, screen: NSScreen?) -> CGRect {
        // Get padded bounds only if padding can be applied
        if !disablePadding, PaddingSettings.enablePadding,
           Defaults[.paddingMinimumScreenSize] == .zero || screen?.diagonalSize ?? .zero > Defaults[.paddingMinimumScreenSize] {
            getPaddedBounds(originalBounds)
        } else {
            originalBounds
        }
    }

    /// Calculates the target frame for the specified window action based on the direction, window, bounds, and whether it is a preview.
    /// - Parameters:
    ///   - direction: the direction of the window action.
    ///   - window: the window to be manipulated.
    ///   - bounds: the bounds within which the window should be manipulated.
    ///   - isPreview: whether the action is being performed on a preview window.
    ///   - proportionalFrame: optional proportional frame when moving between screens.
    /// - Returns: the calculated target frame for the specified window action.
    private func calculateTargetFrame(_ direction: WindowDirection, _ window: Window?, _ bounds: CGRect, _ isPreview: Bool, proportionalFrame: CGRect? = nil) -> CGRect {
        var result: CGRect = .zero

        if direction.frameMultiplyValues != nil {
            // When moving between screens with a proportional frame, use proportional sizing
            if let proportionalFrame {
                result = applyProportionalFrame(proportionalFrame, bounds)
            } else {
                result = applyFrameMultiplyValues(bounds)
            }

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

            result = calculateSizeAdjustment(frameToResizeFrom, bounds)

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

            result = calculateSizeAdjustment(frameToResizeFrom, bounds)

        } else if direction.willMove {
            // Return final frame of preview
            if Defaults[.previewVisibility], !isPreview {
                return LoopManager.lastTargetFrame
            }

            let frameToResizeFrom = LoopManager.lastTargetFrame

            result = calculatePositionAdjustment(frameToResizeFrom)

        } else if direction.isCustomizable {
            result = calculateCustomFrame(window, bounds)

        } else if direction == .center {
            result = calculateCenterFrame(window, bounds)

        } else if direction == .macOSCenter {
            result = calculateMacOSCenterFrame(window, bounds)

        } else if direction == .undo, let window {
            result = getLastActionFrame(window, bounds)

        } else if direction == .initialFrame, let window {
            result = getInitialFrame(window)

        } else if direction == .maximizeHeight, let window {
            result = CGRect(
                x: window.frame.minX,
                y: bounds.minY,
                width: window.frame.width,
                height: bounds.height
            )
        } else if direction == .maximizeWidth, let window {
            result = CGRect(
                x: bounds.minX,
                y: window.frame.minY,
                width: bounds.width,
                height: window.frame.height
            )
        } else if direction == .unstash, let window {
            result = getInitialFrame(window)
        }

        return result
    }

    /// Applies the window direction's frame multiply values to the given bounds.
    /// - Parameter bounds: the bounds to which the frame multiply values will be applied on.
    /// - Returns: a new `CGRect` with the frame multiply values applied.
    private func applyFrameMultiplyValues(_ bounds: CGRect) -> CGRect {
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

    /// Applies a proportional frame (from a previous screen) to new bounds.
    /// This is used when moving windows between screens to maintain their relative size.
    /// - Parameters:
    ///   - proportionalFrame: The proportional frame with values between 0.0 and 1.0
    ///   - bounds: The new screen bounds to apply the proportions to
    /// - Returns: A new `CGRect` with the proportional frame applied to the new bounds
    private func applyProportionalFrame(_ proportionalFrame: CGRect, _ bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.origin.x + (bounds.width * proportionalFrame.minX),
            y: bounds.origin.y + (bounds.height * proportionalFrame.minY),
            width: bounds.width * proportionalFrame.width,
            height: bounds.height * proportionalFrame.height
        )
    }

    /// Calculates the user-specified custom frame relative to the provided bounds.
    /// - Parameters:
    ///   - window: the window to be manipulated.
    ///   - bounds: the bounds within which the window should be manipulated.
    /// - Returns: the calculated custom frame based on the specified parameters.
    private func calculateCustomFrame(_ window: Window?, _ bounds: CGRect) -> CGRect {
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
                let yOffset = getMacOSCenterYOffset(result.height, screenHeight: bounds.height)
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
    private func calculateCenterFrame(_ window: Window?, _ bounds: CGRect) -> CGRect {
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
    private func calculateMacOSCenterFrame(_ window: Window?, _ bounds: CGRect) -> CGRect {
        let windowSize: CGSize = if let window {
            window.size
        } else {
            .init(width: bounds.width / 2, height: bounds.height / 2)
        }

        let yOffset = getMacOSCenterYOffset(
            windowSize.height,
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
    private func getMacOSCenterYOffset(_ windowHeight: CGFloat, screenHeight: CGFloat) -> CGFloat {
        let halfScreenHeight = screenHeight / 2
        let windowHeightPercent = windowHeight / screenHeight
        return (0.5 * windowHeightPercent - 0.5) * halfScreenHeight
    }

    /// Retrieves the last action frame for the specified window, based on the last action recorded in `WindowRecords`.
    /// - Parameters:
    ///   - window: the window for which the last action frame is to be retrieved.
    ///   - bounds: the bounds within which the window should be manipulated.
    /// - Returns: the frame of the last action performed on the window, or the current frame if no last action is found.
    private func getLastActionFrame(_ window: Window, _ bounds: CGRect) -> CGRect {
        if let previousAction = WindowRecords.getLastAction(for: window) {
            Self.logger.info("Last action was \(previousAction.direction.debugDescription) (name: \(previousAction.name ?? "nil"))")
            return previousAction.getFrame(window: window, bounds: bounds)
        } else {
            Self.logger.info("Didn't find frame to undo; using current frame")
            return window.frame
        }
    }

    /// Retrieves the initial frame for the specified window, based on the initial frame recorded in `WindowRecords`.
    /// - Parameter window: the window for which the initial frame is to be retrieved.
    /// - Returns: the initial frame of the window, or the current frame if no initial frame is found.
    private func getInitialFrame(_ window: Window) -> CGRect {
        if let initialFrame = WindowRecords.getInitialFrame(for: window) {
            return initialFrame
        } else {
            Self.logger.info("Didn't find initial frame; using current frame")
            return window.frame
        }
    }

    /// Calculates the size adjustment for the specified frame based on the bounds and the direction of the action.
    /// - Parameters:
    ///   - frameToResizeFrom: the frame to apply the size adjustment to.
    ///   - bounds: the bounds within which the frame should be resized.
    /// - Returns: the adjusted frame after applying the size adjustment based on the direction and bounds.
    private func calculateSizeAdjustment(_ frameToResizeFrom: CGRect, _ bounds: CGRect) -> CGRect {
        var result = frameToResizeFrom
        let totalBounds: Edge.Set = [.top, .bottom, .leading, .trailing]
        let step = Defaults[.sizeIncrement] * ((direction == .larger || direction.willGrow) ? -1 : 1)

        let padding = PaddingSettings.padding
        let previewPadding = Defaults[.previewPadding]
        let totalHorizontalPadding = padding.left + padding.right
        let totalVerticalPadding = padding.totalTopPadding + padding.bottom
        let minWidth = totalHorizontalPadding + previewPadding + 100
        let minHeight = totalVerticalPadding + previewPadding + 100

        if LoopManager.sidesToAdjust == nil {
            let edgesTouchingBounds = frameToResizeFrom.getEdgesTouchingBounds(bounds)
            LoopManager.sidesToAdjust = totalBounds.subtracting(edgesTouchingBounds)
        }

        if let edgesToInset = LoopManager.sidesToAdjust {
            if edgesToInset.isEmpty || edgesToInset.contains(totalBounds) {
                result = result.inset(
                    by: step,
                    minSize: .init(
                        width: minWidth,
                        height: minHeight
                    )
                )
            } else {
                result = result.padding(edgesToInset, step)

                if result.width < minWidth {
                    result.size.width = minWidth
                    result.origin.x = frameToResizeFrom.midX - minWidth / 2
                }

                if result.height < minHeight {
                    result.size.height = minHeight
                    result.origin.y = frameToResizeFrom.midY - minHeight / 2
                }
            }
        }

        if result.size.approximatelyEqual(to: LoopManager.lastTargetFrame.size, tolerance: 2) {
            result = LoopManager.lastTargetFrame
        }

        return result
    }

    /// Calculates the position adjustment for the specified frame based on the direction of the action.
    /// - Parameter frameToResizeFrom: the frame to apply the position adjustment to.
    /// - Returns: the adjusted frame after applying the position adjustment based on the direction.
    private func calculatePositionAdjustment(_ frameToResizeFrom: CGRect) -> CGRect {
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

    /// Retrieves the padded bounds for the specified bounds, based on user preferences.
    /// - Parameter bounds: the bounds to be padded.
    /// - Returns: the padded bounds with the specified padding applied.
    private func getPaddedBounds(_ bounds: CGRect) -> CGRect {
        let padding = PaddingSettings.padding

        var bounds = bounds
        bounds = bounds.padding(.top, padding.totalTopPadding)
        bounds = bounds.padding(.bottom, padding.bottom)
        bounds = bounds.padding(.leading, padding.left)
        bounds = bounds.padding(.trailing, padding.right)

        return bounds
    }

    /// Applies inner padding to the specified window frame based on the direction and bounds.
    /// "Inner padding" is the padding applied to the sides of the window frame, which aren't touching the side of the screen.
    /// - Parameters:
    ///   - windowFrame: the frame of the window to which padding will be applied.
    ///   - bounds: the bounds within which the window should be padded.
    ///   - screen: the screen on which the bounds are located. This is used to determine if padding should be applied based on the screen size (if applicable).
    /// - Returns: the window frame with the specified padding applied.
    private func applyInnerPadding(_ windowFrame: CGRect, _ bounds: CGRect, _ screen: NSScreen? = nil) -> CGRect {
        guard PaddingSettings.enablePadding, !direction.willMove else {
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

        let padding = PaddingSettings.padding
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

extension WindowAction: CustomDebugStringConvertible {
    var debugDescription: String {
        "WindowAction(direction: \(direction), name: \(getName()))"
    }
}
