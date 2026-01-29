//
//  WindowActionIndicatorService.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-19.
//

import AppKit
import Defaults

@MainActor
final class WindowActionIndicatorService {
    private let radialMenuController = RadialMenuController()
    private let previewController = PreviewController()

    func openAndUpdate(context: ResizeContext) {
        if Defaults[.hideOnNoSelection], context.action.direction == .noSelection {
            closeAll()
            return
        }

        if Defaults[.previewVisibility] {
            previewController.open(context: context)
        }

        if Defaults[.radialMenuVisibility] {
            radialMenuController.open(context: context)
        }
    }

    func closeAll() {
        radialMenuController.close()
        previewController.close()
    }
}
