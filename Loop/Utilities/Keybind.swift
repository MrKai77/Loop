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
