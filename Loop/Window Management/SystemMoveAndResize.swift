//
//  SystemMoveAndResize.swift
//  Loop
//
//  Created by Kai Azim on 2024-09-18.
//

import SwiftUI

// This is a direct mapping of the menu items in the "Move & Resize" menu
@available(macOS 15, *)
enum SystemMoveAndResize: String {
    // General
    case minimize = "Minimize"
    case zoom = "Zoom"
    case fill = "Fill"
    case center = "Center"
    static var generalActions: [SystemMoveAndResize] {
        [.minimize, .zoom, .fill, .center]
    }

    // Halves
    case left = "Left"
    case right = "Right"
    case top = "Top"
    case bottom = "Bottom"
    static var halvesActions: [SystemMoveAndResize] {
        [.left, .right, .top, .bottom]
    }

    // Quarters
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
    static var quartersActions: [SystemMoveAndResize] {
        [.topLeft, .topRight, .bottomLeft, .bottomRight]
    }

    // Arrange
    case leftAndRight = "Left & Right"
    case rightAndLeft = "Right & Left"
    case topAndBottom = "Top & Bottom"
    case bottomAndTop = "Bottom & Top"
    case quarters = "Quarters"
    static var arrangeActions: [SystemMoveAndResize] {
        [.leftAndRight, .rightAndLeft, .topAndBottom, .bottomAndTop, .quarters]
    }

    case returnToPreviousSize = "Return to Previous Size"

    func perform(on app: NSRunningApplication) {
        do {
            let item = try getItem(for: app)
            try item?.performAction(.press)
        } catch {
            print("Error while performing system move/resize action: \(error)")
        }
    }

    private func getItem(for app: NSRunningApplication) throws -> AXUIElement? {
        let moveAndResize = "Move & Resize"
        let pid = app.processIdentifier

        // Scan menubar items
        let element = AXUIElementCreateApplication(pid)
        let menubar: CFTypeRef? = try element.getValue(.menuBar)
        let menubarItems = (menubar as! AXUIElement).children
        let windowMenu = try menubarItems.first {
            try $0.getValue(.title) == "Window"
        }

        if SystemMoveAndResize.generalActions.contains(self) {
            let moveAndResizeItems = windowMenu?.children.first?.children
            return try moveAndResizeItems?
                .first(where: { try $0.getValue(.title) == rawValue }) ?? moveAndResizeItems?
                .first(where: { try ($0.getValue(.title) as String?)?.localizedCaseInsensitiveContains(rawValue) ?? false })
        } else {
            if let items = windowMenu?.children.first?.children,
               let resizeItems = try items.first(where: { try $0.getValue(.title) == moveAndResize })?.children.first?.children {
                return try resizeItems
                    .first(where: { try $0.getValue(.title) == rawValue }) ?? resizeItems
                    .first(where: { try ($0.getValue(.title) as String?)?.localizedCaseInsensitiveContains(rawValue) ?? false })
            }
        }

        return nil
    }
}

@available(macOS 15, *)
extension WindowDirection {
    var systemEquivalent: SystemMoveAndResize? {
        switch self {
        case .minimize:
            .minimize
        case .maximize:
            .fill
        case .center:
            .center
        case .leftHalf:
            .left
        case .rightHalf:
            .right
        case .topHalf:
            .top
        case .bottomHalf:
            .bottom
        case .topLeftQuarter:
            .topLeft
        case .topRightQuarter:
            .topRight
        case .bottomLeftQuarter:
            .bottomLeft
        case .bottomRightQuarter:
            .bottomRight
        case .initialFrame:
            .returnToPreviousSize
        default:
            nil
        }
    }
}
