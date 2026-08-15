//
//  AltDragConfiguration.swift
//  Loop
//
//  Created for Loop Fork.
//

import Defaults
import SwiftUI

enum AltDragModifier: Int, Defaults.Serializable, CaseIterable, Identifiable {
    var id: Self { self }

    case option = 0
    case command = 1
    case control = 2
    case commandOption = 3
    case controlOption = 4
    case fn = 5

    var name: LocalizedStringKey {
        switch self {
        case .option:
            "Option (⌥)"
        case .command:
            "Command (⌘)"
        case .control:
            "Control (⌃)"
        case .commandOption:
            "Command + Option (⌘⌥)"
        case .controlOption:
            "Control + Option (⌃⌥)"
        case .fn:
            "Function (fn / 🌐)"
        }
    }

    func matches(flags: CGEventFlags) -> Bool {
        let hasOption = flags.contains(.maskAlternate)
        let hasCommand = flags.contains(.maskCommand)
        let hasControl = flags.contains(.maskControl)
        let hasSecondaryFn = flags.contains(.maskSecondaryFn)

        switch self {
        case .option:
            return hasOption && !hasCommand && !hasControl
        case .command:
            return hasCommand && !hasOption && !hasControl
        case .control:
            return hasControl && !hasOption && !hasCommand
        case .commandOption:
            return hasCommand && hasOption && !hasControl
        case .controlOption:
            return hasControl && hasOption && !hasCommand
        case .fn:
            return hasSecondaryFn
        }
    }
}

enum AltDragResizeButton: Int, Defaults.Serializable, CaseIterable, Identifiable {
    var id: Self { self }

    case rightClick = 0
    case shiftLeftClick = 1
    case middleClick = 2

    var name: LocalizedStringKey {
        switch self {
        case .rightClick:
            "Right Click"
        case .shiftLeftClick:
            "Shift + Left Click"
        case .middleClick:
            "Middle Click"
        }
    }
}

enum AltDragAnchor {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case center

    static func calculateAnchor(for point: CGPoint, in rect: CGRect) -> AltDragAnchor {
        let isLeft = point.x < rect.midX
        let isTop = point.y < rect.midY

        switch (isLeft, isTop) {
        case (true, true):
            return .bottomRight // Dragging top-left moves top-left, anchors bottom-right
        case (false, true):
            return .bottomLeft  // Dragging top-right moves top-right, anchors bottom-left
        case (true, false):
            return .topRight    // Dragging bottom-left moves bottom-left, anchors top-right
        case (false, false):
            return .topLeft     // Dragging bottom-right moves bottom-right, anchors top-left
        }
    }
}
