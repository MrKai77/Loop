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

    // Returns the window frame within the boundaries of (0, 0) to (1, 1)
    // Will be on the screen with mouse if needed.
    func getFrameMultiplyValues(window: Window?) -> CGRect {
        guard self.direction != .cycle else { return .zero }

        let bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        var result = CGRect.zero

        if let frameMultiplyValues = direction.frameMultiplyValues {
            result.origin.x = bounds.width * frameMultiplyValues.minX
            result.origin.y = bounds.height * frameMultiplyValues.minY
            result.size.width = bounds.width * frameMultiplyValues.width
            result.size.height = bounds.height * frameMultiplyValues.height

        } else if direction == .center,
                  let window = window,
                  let screenFrame = NSScreen.screenWithMouse?.visibleFrame {
            let windowSize = window.size
            result = CGRect(
                x: (screenFrame.midX - windowSize.width / 2) / screenFrame.width,
                y: (screenFrame.midY - windowSize.height / 2) / screenFrame.height,
                width: windowSize.width / screenFrame.width,
                height: windowSize.height / screenFrame.height
            )

        } else if direction == .macOSCenter,
                  let window = window,
                  let screenFrame = NSScreen.screenWithMouse?.visibleFrame {
            let windowSize = window.size
            let yOffset = WindowEngine.getMacOSCenterYOffset(windowSize.height, screenHeight: screenFrame.height)
            result = CGRect(
                x: (screenFrame.midX - windowSize.width / 2) / screenFrame.width,
                y: ((screenFrame.midY - windowSize.height / 2) + yOffset) / screenFrame.height,
                width: windowSize.width / screenFrame.width,
                height: windowSize.height / screenFrame.height
            )

        } else if direction == .custom {
            result = calculateCustomFrame(window, bounds)
        }

        return result
    }

    private func calculateCustomFrame(_ window: Window?, _ bounds: CGRect) -> CGRect {
        var result: CGRect = .zero

        if let sizeMode, sizeMode == .preserveSize {
            guard
                let screenFrame = NSScreen.screenWithMouse?.visibleFrame,
                let window = window
            else {
                return result
            }
            let windowSize = window.size
            result.size.width = windowSize.width / screenFrame.width
            result.size.height = windowSize.height / screenFrame.height

        } else if let sizeMode, sizeMode == .initialSize {
            guard
                let screenFrame = NSScreen.screenWithMouse?.visibleFrame,
                let window = window,
                let initialFrame = WindowRecords.getInitialFrame(for: window)
            else {
                return result
            }

            result.size.width = initialFrame.size.width / screenFrame.width
            result.size.height = initialFrame.size.height / screenFrame.height

        } else {    // sizeMode would be custom
            switch unit {
            case .pixels:
                guard let screenFrame = NSScreen.screenWithMouse?.frame else { return result }
                result.size.width = (width ?? screenFrame.width) / screenFrame.width
                result.size.height = (height ?? screenFrame.height) / screenFrame.height
            default:
                result.size.width = bounds.width * ((width ?? 0) / 100.0)
                result.size.height = bounds.height * ((height ?? 0) / 100.0)
            }
        }

        if let positionMode, positionMode == .coordinates {
            switch unit {
            case .pixels:
                guard let screenFrame = NSScreen.screenWithMouse?.frame else { return result }
                result.origin.x = (xPoint ?? screenFrame.width) / screenFrame.width
                result.origin.y = (yPoint ?? screenFrame.height) / screenFrame.height
            default:
                result.origin.x = bounds.width * ((xPoint ?? 0) / 100.0)
                result.origin.y = bounds.height * ((yPoint ?? 0) / 100.0)
            }

            // "Crops" the result to be within the screen's bounds
            result = bounds.intersection(result)
        } else {
            switch anchor {
            case .topLeft:
                break
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
            case .none:
                break
            }
        }

        return result
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
}
