//
//  WindowAction+Image.swift
//  Loop
//
//  Created by phlpsong on 2024/3/30.
//

import Luminare
import SwiftUI

enum WindowActionImage {
    case systemImage(String)
    case resource(ImageResource)

    var image: Image {
        switch self {
        case let .systemImage(string):
            Image(systemName: string)
        case let .resource(resource):
            Image(resource)
        }
    }

    var nsImage: NSImage {
        switch self {
        case let .systemImage(string):
            let image = NSImage(systemSymbolName: string, accessibilityDescription: nil)
            return image?.withSymbolConfiguration(.init(pointSize: 20, weight: .bold)) ?? image ?? NSImage()
        case let .resource(resource):
            return NSImage(resource: resource)
        }
    }
}

extension WindowAction {
    var image: WindowActionImage? {
        switch direction {
        case .noAction:
            .systemImage("questionmark")
        case .undo:
            .systemImage("arrow.uturn.backward")
        case .initialFrame:
            .systemImage("backward.end.fill")
        case .hide:
            .systemImage("eye.slash")
        case .minimize:
            .systemImage("arrow.down.right.and.arrow.up.left")
        case .minimizeOthers:
            .systemImage("arrow.down.right.and.arrow.up.left")
        case .maximizeHeight:
            .systemImage("arrow.up.and.down")
        case .maximizeWidth:
            .systemImage("arrow.left.and.right")
        case .nextScreen:
            .systemImage("arrow.forward")
        case .previousScreen:
            .systemImage("arrow.backward")
        case .leftScreen:
            .systemImage("arrow.left.to.line")
        case .rightScreen:
            .systemImage("arrow.right.to.line")
        case .topScreen:
            .systemImage("arrow.up.to.line")
        case .bottomScreen:
            .systemImage("arrow.down.to.line")
        case .fillAvailableSpace, .larger, .scaleUp:
            .systemImage("arrow.up.left.and.arrow.down.right")
        case .smaller, .scaleDown:
            .systemImage("arrow.down.right.and.arrow.up.left")
        case .shrinkTop, .growBottom, .moveDown:
            .systemImage("arrow.down")
        case .shrinkBottom, .growTop, .moveUp:
            .systemImage("arrow.up")
        case .shrinkRight, .growLeft, .moveLeft:
            .systemImage("arrow.left")
        case .shrinkLeft, .growRight, .moveRight:
            .systemImage("arrow.right")
        case .shrinkHorizontal:
            .systemImage("arrow.right.and.line.vertical.and.arrow.left")
        case .growHorizontal:
            .systemImage("arrow.left.and.line.vertical.and.arrow.right")
        case .shrinkVertical:
            .systemImage("arrow.down.and.line.horizontal.and.arrow.up")
        case .growVertical:
            .systemImage("arrow.up.and.line.horizontal.and.arrow.down")
        case .focusLeft:
            .systemImage("chevron.left")
        case .focusRight:
            .systemImage("chevron.right")
        case .focusUp:
            .systemImage("chevron.up")
        case .focusDown:
            .systemImage("chevron.down")
        case .focusNextInStack:
            .systemImage("rectangle.stack")
        default:
            nil
        }
    }

    /// Used in icons when a default image doesn't exist for this
    /// action, and a valid frame couldn't be computed.
    var backupImage: WindowActionImage? {
        switch direction {
        case .custom:
            .systemImage("slider.horizontal.3")
        case .cycle:
            .systemImage("repeat")
        case .stash:
            .systemImage("archivebox.fill")
        case .unstash:
            .systemImage("arrow.uturn.backward")
        default:
            nil
        }
    }
}
