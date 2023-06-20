//
//  LoopTriggerKeys.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-19.
//

import Foundation

struct LoopTriggerKeys {
    var symbol: String
    var keySymbol: String
    var description: String
    var keycode: UInt16
    
    static let options: [LoopTriggerKeys] = [
        LoopTriggerKeys(
            symbol: "globe",
            keySymbol: "custom.globe.rectangle.fill",
            description: "Globe",
            keycode: KeyCode.function
        ),
        LoopTriggerKeys(
            symbol: "control",
            keySymbol: "custom.control.rectangle.fill",
            description: "Right Control",
            keycode: KeyCode.rightControl
        ),
        LoopTriggerKeys(
            symbol: "option",
            keySymbol: "custom.option.rectangle.fill",
            description: "Right Option",
            keycode: KeyCode.rightOption
        ),
        LoopTriggerKeys(
            symbol: "command",
            keySymbol: "custom.command.rectangle.fill",
            description: "Right Command",
            keycode: KeyCode.rightCommand
        ),
    ]
}
