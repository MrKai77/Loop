//
//  PaddingModel.swift
//  Loop
//
//  Created by Kai Azim on 2024-02-01.
//

import SwiftUI
import Defaults

struct PaddingModel: Codable, Defaults.Serializable {
    var window: CGFloat
    var top: CGFloat
    var bottom: CGFloat
    var right: CGFloat
    var left: CGFloat

    var configureScreenPadding: Bool

    static var defaultConfig = PaddingModel(
        window: 0,
        top: 0,
        bottom: 0,
        right: 0,
        left: 0,
        configureScreenPadding: false
    )
}
