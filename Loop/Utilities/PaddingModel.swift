//
//  PaddingModel.swift
//  Loop
//
//  Created by Kai Azim on 2024-02-01.
//

import SwiftUI
import Defaults

struct PaddingModel: Codable, Defaults.Serializable {
    var window: CGFloat {
        didSet { window = max(window, 0) }
    }
    var top: CGFloat {
        didSet { top = max(top, 0) }
    }
    var bottom: CGFloat {
        didSet { bottom = max(bottom, 0) }
    }
    var right: CGFloat {
        didSet { right = max(right, 0) }
    }
    var left: CGFloat {
        didSet { left = max(left, 0) }
    }

    var configureScreenPadding: Bool

    static var zero = PaddingModel(
        window: 0,
        top: 0,
        bottom: 0,
        right: 0,
        left: 0,
        configureScreenPadding: false
    )
}
