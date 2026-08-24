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

    /// Repositions the radial menu when the cursor enters a different display.
    ///
    /// The radial menu normally remains anchored to the location where Loop was
    /// triggered. This update is intentionally separate from `openAndUpdate` so
    /// mouse movement can relocate the menu even when the selected action does
    /// not change.
    func updateRadialMenuPosition(at mousePosition: CGPoint) {
        radialMenuController.updatePositionIfNeeded(at: mousePosition)
    }

    func closeAll() {
        radialMenuController.close()
        previewController.close()
    }
}
