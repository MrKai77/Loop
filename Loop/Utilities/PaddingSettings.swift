//
//  PaddingSettings.swift
//  Loop
//
//  Created by Kai Azim on 2025-08-29.
//

import Defaults
import Foundation

enum PaddingSettings {
    static var enablePadding: Bool {
        if #available(macOS 15, *), Defaults[.useSystemWindowManagerWhenAvailable] {
            SystemWindowManager.MoveAndResize.enablePadding
        } else {
            Defaults[.enablePadding]
        }
    }

    static var padding: PaddingModel {
        if #available(macOS 15, *), Defaults[.useSystemWindowManagerWhenAvailable] {
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
            return Defaults[.padding]
        }
    }
}
