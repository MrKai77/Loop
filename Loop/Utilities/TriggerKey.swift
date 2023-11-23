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
    var symbolName: String
    var keycode: CGKeyCode
    var doubleClickRecommended: Bool = false

    static let options: [TriggerKey] = [
        TriggerKey(
            name: "Globe",
            symbolName: "globe",
            keycode: .kVK_Function
        ),
        TriggerKey(
            name: "Left Control",
            symbolName: "control",
            keycode: .kVK_Control,
            doubleClickRecommended: true
        ),
        TriggerKey(
            name: "Right Control",
            symbolName: "control",
            keycode: .kVK_RightControl
        ),
        TriggerKey(
            name: "Left Option",
            symbolName: "option",
            keycode: .kVK_Option,
            doubleClickRecommended: true
        ),
        TriggerKey(
            name: "Right Option",
            symbolName: "option",
            keycode: .kVK_RightOption
        ),
        TriggerKey(
            name: "Left Command",
            symbolName: "command",
            keycode: .kVK_Command,
            doubleClickRecommended: true
        ),
        TriggerKey(
            name: "Right Command",
            symbolName: "command",
            keycode: .kVK_RightCommand
        ),
        TriggerKey(
            name: "Left Shift",
            symbolName: "shift",
            keycode: .kVK_Shift,
            doubleClickRecommended: true
        ),
        TriggerKey(
            name: "Right Shift",
            symbolName: "shift",
            keycode: .kVK_RightShift
        )
    ]
}
