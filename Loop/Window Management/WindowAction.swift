//
//  Keybind.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-28.
//

import SwiftUI
import Defaults

struct WindowAction: Codable, Identifiable, Hashable, Equatable, Defaults.Serializable {
    var id: UUID

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

    init(_ direction: WindowDirection) {
        self.init(direction, keybind: [])
    }

    init(_ name: String? = nil, _ cycle: [WindowAction], _ keybind: Set<CGKeyCode> = []) {
        self.init(.cycle, keybind: keybind, name: name, cycle: cycle)
    }

    var direction: WindowDirection
    var keybind: Set<CGKeyCode>

    // MARK: CUSTOM KEYBINDS
    var name: String?
    var unit: CustomWindowActionUnit?
    var anchor: CustomWindowActionAnchor?
    var sizeMode: CustomWindowActionSizeMode?
    var width: Double?
    var height: Double?
    var positionMode: CustomWindowActionPositionMode?
    var xPoint: Double?
    var yPoint: Double?

    var cycle: [WindowAction]?

    static func getAction(for keybind: Set<CGKeyCode>) -> WindowAction? {
        for keybinding in Defaults[.keybinds] where keybinding.keybind == keybind {
            return keybinding
        }
        return nil
    }

    func getEdgesTouchingScreen() -> Edge.Set {
        guard let frameMultiplyValues = direction.frameMultiplyValues else {
            return []
        }

        var result: Edge.Set = []

        if frameMultiplyValues.minX == 0 {
            result.insert(.leading)
        }
        if frameMultiplyValues.maxX == 1 {
            result.insert(.trailing)
        }
        if frameMultiplyValues.minY == 0 {
            result.insert(.top)
        }
        if frameMultiplyValues.maxY == 1 {
            result.insert(.bottom)
        }

        return result
    }

    func getFrame(window: Window?, bounds: CGRect) -> CGRect {
        guard self.direction != .cycle, self.direction != .noAction else {
            return NSRect(origin: bounds.center, size: .zero)
        }
        var result = CGRect(origin: bounds.origin, size: .zero)

        if let frameMultiplyValues = direction.frameMultiplyValues {
            result.origin.x += bounds.width * frameMultiplyValues.minX
            result.origin.y += bounds.height * frameMultiplyValues.minY
            result.size.width = bounds.width * frameMultiplyValues.width
            result.size.height = bounds.height * frameMultiplyValues.height

        } else if direction == .custom {
            result = calculateCustomFrame(window, bounds)

        } else if direction == .center, let window = window {
            let windowSize = window.size
            result = CGRect(
                origin: CGPoint(
                    x: bounds.midX - (windowSize.width / 2),
                    y: bounds.midY - (windowSize.height / 2)
                ),
                size: windowSize
            )

        } else if direction == .macOSCenter, let window = window {
            let windowSize = window.size
            let yOffset = WindowEngine.getMacOSCenterYOffset(
                windowSize.height,
                screenHeight: bounds.height
            )

            result = CGRect(
                origin: CGPoint(
                    x: bounds.midX - (windowSize.width / 2),
                    y: bounds.midY - (windowSize.height / 2) + yOffset
                ),
                size: windowSize
            )
        } else if direction == .undo, let window = window {
            if let previousAction = WindowRecords.getLastAction(for: window) {
                print("Last action was \(previousAction.direction) (name: \(previousAction.name ?? "nil"))")
                result = previousAction.getFrame(window: window, bounds: bounds)
            } else {
                print("Didn't find frame to undo; using current frame")
                result = window.frame
            }

        } else if direction == .initialFrame, let window = window {
            if let initialFrame = WindowRecords.getInitialFrame(for: window) {
                result = initialFrame
            } else {
                print("Didn't find initial frame; using current frame")
                result = window.frame
            }
        }

        result = self.applyPadding(result, bounds)

        return result
    }

    private func calculateCustomFrame(_ window: Window?, _ bounds: CGRect) -> CGRect {
        var result = CGRect(origin: bounds.origin, size: .zero)

        // SIZE
        if let sizeMode, sizeMode == .preserveSize, let window = window {
            result.size = window.size

        } else if let sizeMode, sizeMode == .initialSize, let window = window {
            if let initialFrame = WindowRecords.getInitialFrame(for: window) {
                result.size = initialFrame.size
            }

        } else {    // sizeMode would be custom
            switch unit {
            case .pixels:
                result.size.width = width ?? result.size.width
                result.size.height = height ?? result.size.height
            default:
                if let width = width {
                    result.size.width = bounds.width * (width / 100.0)
                }

                if let height = height {
                    result.size.height = bounds.height * (height / 100.0)
                }
            }
        }

        // POSITION
        if let positionMode, positionMode == .coordinates {
            switch unit {
            case .pixels:
                // Note that bounds are ignored deliberately here
                result.origin.x += xPoint ?? .zero
                result.origin.y += yPoint ?? .zero
            default:
                if let xPoint = xPoint {
                    result.origin.x += bounds.width * (xPoint / 100.0)
                }

                if let yPoint = yPoint {
                    result.origin.y += bounds.width * (yPoint / 100.0)
                }
            }
        } else {    // positionMode would be generic
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
                let yOffset = WindowEngine.getMacOSCenterYOffset(result.height, screenHeight: bounds.height)
                result.origin.x = bounds.midX - result.width / 2
                result.origin.y = (bounds.midY - result.height / 2) + yOffset
            default:
                break
            }
        }

        return result
    }

    /// Apply padding on a CGRect, using the provided WindowDirection
    /// - Parameters:
    ///   - windowFrame: The frame the window WILL be resized to
    ///   - direction: The direction the window WILL be resized to
    /// - Returns: CGRect with padding applied
    private func applyPadding(_ windowFrame: CGRect, _ screenFrame: CGRect) -> CGRect {
        let padding = Defaults[.padding]
        let halfPadding = padding.window / 2

        var bounds = screenFrame
        bounds = bounds.padding(.top, padding.totalTopPadding)
        bounds = bounds.padding(.bottom, padding.bottom)
        bounds = bounds.padding(.leading, padding.left)
        bounds = bounds.padding(.trailing, padding.right)

        var paddedWindowFrame = windowFrame.intersection(bounds)

        if direction == .macOSCenter,
           windowFrame.height >= bounds.height {

            paddedWindowFrame.origin.y = bounds.minY
            paddedWindowFrame.size.height = bounds.height
        }

        if direction == .center || direction == .macOSCenter {
            return paddedWindowFrame
        }

        if paddedWindowFrame.minX != bounds.minX {
            paddedWindowFrame = paddedWindowFrame.padding(.leading, halfPadding)
        }

        if paddedWindowFrame.maxX != bounds.maxX {
            paddedWindowFrame = paddedWindowFrame.padding(.trailing, halfPadding)
        }

        if paddedWindowFrame.minY != bounds.minY {
            paddedWindowFrame = paddedWindowFrame.padding(.top, halfPadding)
        }

        if paddedWindowFrame.maxY != bounds.maxY {
            paddedWindowFrame = paddedWindowFrame.padding(.bottom, halfPadding)
        }

        return paddedWindowFrame
    }
}
