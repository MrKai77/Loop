//
//  PaddingModel.swift
//  Loop
//
//  Created by Kai Azim on 2024-02-01.
//

import Defaults
import SwiftUI

struct PaddingModel: Codable, Defaults.Serializable, Hashable {
    var window: CGFloat
    var externalBar: CGFloat
    var top: CGFloat
    var bottom: CGFloat
    var right: CGFloat
    var left: CGFloat

    var configureScreenPadding: Bool

    var totalTopPadding: CGFloat {
        top + externalBar
    }

    static var zero = PaddingModel(
        window: 0,
        externalBar: 0,
        top: 0,
        bottom: 0,
        right: 0,
        left: 0,
        configureScreenPadding: false
    )

    var allEqual: Bool {
        window == top && window == bottom && window == right && window == left
    }

    func apply(on initial: CGRect) -> CGRect {
        initial
            .padding(.leading, left)
            .padding(.trailing, right)
            .padding(.bottom, bottom)
            .padding(.top, totalTopPadding)
    }
}
