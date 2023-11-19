//
//  LoopTriggerKeys.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-19.
//

import Foundation
import Defaults
import CoreGraphics

struct TriggerKey: Codable, Hashable, Defaults.Serializable {
    var name: String
    var symbol: String
    var keySymbol: String
    var keycode: CGKeyCode
    var doubleClickRecommended: Bool = false

    static let options: [TriggerKey] = [
        TriggerKey(
            name: "Globe",
            symbol: "globe",
            keySymbol: "globe",
            keycode: .kVK_Function
        ),
        TriggerKey(
            name: "Left Control",
            symbol: "control",
            keySymbol: "control",
            keycode: .kVK_Control,
            doubleClickRecommended: true
        ),
        TriggerKey(
            name: "Right Control",
            symbol: "control",
            keySymbol: "control",
            keycode: .kVK_RightControl
        ),
        TriggerKey(
            name: "Left Option",
            symbol: "option",
            keySymbol: "option",
            keycode: .kVK_Option,
            doubleClickRecommended: true
        ),
        TriggerKey(
            name: "Right Option",
            symbol: "option",
            keySymbol: "option",
            keycode: .kVK_RightOption
        ),
        TriggerKey(
            name: "Left Command",
            symbol: "command",
            keySymbol: "command",
            keycode: .kVK_Command,
            doubleClickRecommended: true
        ),
        TriggerKey(
            name: "Right Command",
            symbol: "command",
            keySymbol: "command",
            keycode: .kVK_RightCommand
        )
    ]
}
