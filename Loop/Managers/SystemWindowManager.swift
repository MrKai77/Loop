//
//  SystemWindowManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-12-24.
//

import Defaults
import SwiftUI

class SystemWindowManager {
    private static let windowManagerDefaults = UserDefaults(suiteName: "com.apple.WindowManager")
    private static let dockDefaults = UserDefaults(suiteName: "com.apple.dock")

    // MARK: - Stage Manager

    enum StageManager {
        static var enabled: Bool {
            windowManagerDefaults?.bool(forKey: "GloballyEnabled") ?? false
        }

        static var shown: Bool {
            !(windowManagerDefaults?.bool(forKey: "AutoHide") ?? true)
        }

        static var position: Edge {
            dockDefaults?.string(forKey: "orientation") == "left" ? .trailing : .leading
        }
    }

    // MARK: - Move & Resize

    // This is a direct mapping of the menu items in the "Move & Resize" menu
    @available(macOS 15, *)
    enum MoveAndResize: String {
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

        static var generalActions: [MoveAndResize] {
            [.minimize, .zoom, .fill, .center]
        }

        static var halvesActions: [MoveAndResize] {
            [.left, .right, .top, .bottom]
        }

        static var quartersActions: [MoveAndResize] {
            [.topLeft, .topRight, .bottomLeft, .bottomRight]
        }

        static var arrangeActions: [MoveAndResize] {
            [.leftAndRight, .rightAndLeft, .topAndBottom, .bottomAndTop, .quarters]
        }

        func getItem(for app: NSRunningApplication) throws -> AXUIElement? {
            let pid = app.processIdentifier

            // Scan menubar items
            let element = AXUIElementCreateApplication(pid)
            let menubar = try (element.getValue(.menuBar) as CFTypeRef?) as! AXUIElement
            let menubarItems = menubar.children.reversed() // Help menu will be last

            for menubarItem in menubarItems {
                guard let windowMenuItems = menubarItem.children.first?.children else {
                    continue
                }

                if MoveAndResize.generalActions.contains(self),
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

        static var snappingEnabled: Bool {
            windowManagerDefaults?.bool(forKey: "EnableTilingByEdgeDrag") ?? false
        }

        static var padding: CGFloat {
            windowManagerDefaults?.bool(forKey: "EnableTiledWindowMargins") ?? false ? 9 : 0
        }

        static func syncPadding() {
            let newPadding = padding

            Defaults[.enablePadding] = newPadding != 0

            if newPadding != 0 {
                Defaults[.padding] = PaddingModel(
                    window: newPadding,
                    externalBar: 0,
                    top: newPadding,
                    bottom: newPadding,
                    right: newPadding,
                    left: newPadding,
                    configureScreenPadding: false
                )
            }
        }
    }
}

@available(macOS 15, *)
extension WindowDirection {
    var systemEquivalent: SystemWindowManager.MoveAndResize? {
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
