//
//  Keybind.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-28.
//

import SwiftUI
import Defaults

struct Keybind: Codable, Identifiable, Hashable, Defaults.Serializable {
    var id = UUID()

    init(_ direction: WindowDirection, keycode: Set<CGKeyCode>) {
        self.direction = direction
        self.keybind = keycode
    }

    init(_ direction: WindowDirection) {
        self.init(direction, keycode: [])
    }

    var direction: WindowDirection
    var keybind: Set<CGKeyCode>

    // MARK: CUSTOM KEYBINDS
    var name: String = "Custom Action"
    var measureSystem: CustomKeybindMeasureSystem?
    var anchor: CustomKeybindAnchor?
    var width: Double?
    var height: Double?

    static func getKeybind(for keybind: Set<CGKeyCode>) -> Keybind? {
        for keybinding in Defaults[.keybinds] where keybinding.keybind == keybind {
            return keybinding
        }
        return nil
    }

    func previewWindowXOffset(_ parentWidth: CGFloat) -> CGFloat {
        var xLocation = parentWidth * (self.direction.frameMultiplyValues?.minX ?? 0)

        if self.direction == .custom {
            switch self.anchor {
            case .topLeft:
                xLocation = 0
            case .top:
                xLocation = (parentWidth / 2) - (previewWindowWidth(parentWidth) / 2)
            case .topRight:
                xLocation = parentWidth - previewWindowWidth(parentWidth)
            case .right:
                xLocation = parentWidth - previewWindowWidth(parentWidth)
            case .bottomRight:
                xLocation = parentWidth - previewWindowWidth(parentWidth)
            case .bottom:
                xLocation = (parentWidth / 2) - (previewWindowWidth(parentWidth) / 2)
            case .bottomLeft:
                xLocation = 0
            case .left:
                xLocation = 0
            case .center:
                xLocation = (parentWidth / 2) - (previewWindowWidth(parentWidth) / 2)
            default:
                xLocation = 0
            }
        }

        return xLocation
    }

    func previewWindowYOffset(_ parentHeight: CGFloat) -> CGFloat {
        var yLocation = parentHeight * (self.direction.frameMultiplyValues?.minY ?? 0)

        if self.direction == .custom {
            switch self.anchor {
            case .topLeft:
                yLocation = 0
            case .top:
                yLocation = 0
            case .topRight:
                yLocation = 0
            case .right:
                yLocation = (parentHeight / 2) - (previewWindowHeight(parentHeight) / 2)
            case .bottomRight:
                yLocation = parentHeight - previewWindowHeight(parentHeight)
            case .bottom:
                yLocation = parentHeight - previewWindowHeight(parentHeight)
            case .bottomLeft:
                yLocation = parentHeight - previewWindowHeight(parentHeight)
            case .left:
                yLocation = (parentHeight / 2) - (previewWindowHeight(parentHeight) / 2)
            case .center:
                yLocation = (parentHeight / 2) - (previewWindowHeight(parentHeight) / 2)
            default:
                yLocation = 0
            }
        }

        return yLocation
    }

    func previewWindowWidth(_ parentWidth: CGFloat) -> CGFloat {
        var width = parentWidth * (self.direction.frameMultiplyValues?.width ?? 0)

        if self.direction == .custom {
            switch self.measureSystem {
            case .pixels:
                width = self.width ?? 0
            case .percentage:
                width =  parentWidth * ((self.width ?? 100) / 100)
            default:
                width = 0
            }
        }

        return width
    }

    func previewWindowHeight(_ parentHeight: CGFloat) -> CGFloat {
        var height = parentHeight * (self.direction.frameMultiplyValues?.height ?? 0)

        if self.direction == .custom {
            switch self.measureSystem {
            case .pixels:
                height = self.height ?? 0
            case .percentage:
                height =  parentHeight * ((self.height ?? 100) / 100)
            default:
                height = 0
            }
        }

        return height
    }
}

enum CustomKeybindMeasureSystem: Int, Codable, CaseIterable, Identifiable {
    var id: Self { self }

    case pixels = 0
    case percentage = 1

    var label: Text {
        switch self {
        case .pixels:
            Text("\(Image(systemName: "rectangle.checkered")) Pixels")
        case .percentage:
            Text("\(Image(systemName: "percent")) Percentages")
        }
    }

    var postscript: String {
        switch self {
        case .pixels: "px"
        case .percentage: "%"
        }
    }
}

enum CustomKeybindAnchor: Int, Codable, CaseIterable, Identifiable {
    var id: Self { self }

    case topLeft = 0
    case top = 1
    case topRight = 2
    case right = 3
    case bottomRight = 4
    case bottom = 5
    case bottomLeft = 6
    case left = 7
    case center = 8

    var label: Text {
        switch self {
        case .topLeft: Text("\(Image(systemName: "arrow.up.left")) Top Left")
        case .top: Text("\(Image(systemName: "arrow.up")) Top")
        case .topRight: Text("\(Image(systemName: "arrow.up.right")) Top Right")
        case .right: Text("\(Image(systemName: "arrow.right")) Right")
        case .bottomRight: Text("\(Image(systemName: "arrow.down.right")) Bottom Right")
        case .bottom: Text("\(Image(systemName: "arrow.down")) Bottom")
        case .bottomLeft: Text("\(Image(systemName: "arrow.down.left")) Bottom Left")
        case .left: Text("\(Image(systemName: "arrow.left")) Left")
        case .center: Text("\(Image(systemName: "scope")) Center")
        }
    }
}
