//
//  LoopTriggerKeys.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-19.
//

import Foundation
import CoreGraphics

struct LoopTriggerKeys {
    var symbol: String
    var keySymbol: String
    var description: String
    var keycode: CGKeyCode

    static let options: [LoopTriggerKeys] = [
        LoopTriggerKeys(
            symbol: "globe",
            keySymbol: "custom.globe.rectangle.fill",
            description: "Globe",
            keycode: .kVK_Function
        ),
        LoopTriggerKeys(
            symbol: "control",
            keySymbol: "custom.control.rectangle.fill",
            description: "Right Control",
            keycode: .kVK_RightControl
        ),
        LoopTriggerKeys(
            symbol: "option",
            keySymbol: "custom.option.rectangle.fill",
            description: "Right Option",
            keycode: .kVK_RightOption
        ),
        LoopTriggerKeys(
            symbol: "command",
            keySymbol: "custom.command.rectangle.fill",
            description: "Right Command",
            keycode: .kVK_RightCommand
        )
    ]
}
