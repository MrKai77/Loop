//
//  PaddingConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-02-01.
//

import Defaults
import SwiftUI

struct PaddingConfiguration: Codable, Defaults.Serializable, Hashable {
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

    static var zero = PaddingConfiguration(
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

    func applyTo(bounds: CGRect) -> CGRect {
        bounds
            .padding(.leading, left)
            .padding(.trailing, right)
            .padding(.bottom, bottom)
            .padding(.top, totalTopPadding)
    }
}

extension PaddingConfiguration {
    static func getConfiguredPadding(for screen: NSScreen?) -> PaddingConfiguration {
        if #available(macOS 15, *), Defaults[.useSystemWindowManagerWhenAvailable] {
            guard SystemWindowManager.MoveAndResize.enablePadding else {
                return .zero
            }

            let padding = SystemWindowManager.MoveAndResize.padding

            return PaddingConfiguration(
                window: padding,
                externalBar: 0,
                top: padding,
                bottom: padding,
                right: padding,
                left: padding,
                configureScreenPadding: false
            )
        } else {
            let respectsPaddingThreshold = if let screen {
                Defaults[.paddingMinimumScreenSize] == 0 || screen.diagonalSize > Defaults[.paddingMinimumScreenSize]
            } else {
                true
            }
            let enablePadding = Defaults[.enablePadding] && respectsPaddingThreshold

            return enablePadding ? Defaults[.padding] : .zero
        }
    }
}
