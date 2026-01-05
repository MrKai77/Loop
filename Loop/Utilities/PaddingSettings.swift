//
//  PaddingSettings.swift
//  Loop
//
//  Created by Kai Azim on 2025-08-29.
//

import AppKit
import Defaults

enum PaddingSettings {
    static func configuredPadding(for screen: NSScreen?) -> PaddingModel {
        if #available(macOS 15, *), Defaults[.useSystemWindowManagerWhenAvailable] {
            guard SystemWindowManager.MoveAndResize.enablePadding else {
                return .zero
            }

            let padding = SystemWindowManager.MoveAndResize.padding

            return PaddingModel(
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
