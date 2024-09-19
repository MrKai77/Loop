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
    case minimize = "_performMiniaturize:"
    case zoom = "_performZoom:"
    case fill = "_zoomFill:"
    case center = "_zoomCenter:"

    // Halves
    case left = "_zoomLeft:"
    case right = "_zoomRight:"
    case top = "_zoomTop:"
    case bottom = "_zoomBottom:"

    // Quarters
    case topLeft = "_zoomTopLeft:"
    case topRight = "_zoomTopRight:"
    case bottomLeft = "_zoomBottomLeft:"
    case bottomRight = "_zoomBottomRight:"

    // Arrange
    case leftAndRight = "_zoomLeftAndRight:"
    case rightAndLeft = "_zoomRightAndLeft:"
    case topAndBottom = "_zoomTopAndBottom:"
    case bottomAndTop = "_zoomBottomAndTop:"
    case quarters = "_zoomQuarters:"

    case returnToPreviousSize = "_zoomUntile:"

    static var generalActions: [SystemMoveAndResize] {
        [.minimize, .zoom, .fill, .center]
    }

    static var halvesActions: [SystemMoveAndResize] {
        [.left, .right, .top, .bottom]
    }

    static var quartersActions: [SystemMoveAndResize] {
        [.topLeft, .topRight, .bottomLeft, .bottomRight]
    }

    static var arrangeActions: [SystemMoveAndResize] {
        [.leftAndRight, .rightAndLeft, .topAndBottom, .bottomAndTop, .quarters]
    }

    func perform(on app: NSRunningApplication) {
        print("Performing system move/resize action")
        do {
            let item = try getItem(for: app)
            try item?.performAction(.press)
        } catch {
            print("Error while performing system move/resize action: \(error)")
        }
    }

    private func getItem(for app: NSRunningApplication) throws -> AXUIElement? {
        let pid = app.processIdentifier

        // Scan menubar items
        let element = AXUIElementCreateApplication(pid)
        let menubar = try (element.getValue(.menuBar) as CFTypeRef?) as! AXUIElement
        let menubarItems = menubar.children.reversed() // Help menu will be last

        for menubarItem in menubarItems {
            guard let windowMenuItems = menubarItem.children.first?.children else {
                continue
            }

            if SystemMoveAndResize.generalActions.contains(self),
               let menuItem = try windowMenuItems.first(where: { try $0.getValue(.identifier) == rawValue }) {
                return menuItem
            } else {
                let menuItemsWithSubmenu = windowMenuItems.filter { $0.children.first?.children != nil }.map(\.children.first)

                for item in menuItemsWithSubmenu {
                    if let menuItem = try item?.children.first(where: { try $0.getValue(.identifier) as String? == rawValue }) {
                        return menuItem
                    }
                }
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
