//
//  Keybind.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-28.
//

import Cocoa
import Defaults

struct Keybind: Codable, Identifiable, Hashable, Defaults.Serializable {
    var id = UUID()

    init(_ direction: WindowDirection, keycode: Set<CGKeyCode>) {
        self.direction = direction
        self.keybind = keycode
    }

    var direction: WindowDirection
    var keybind: Set<CGKeyCode>
}
