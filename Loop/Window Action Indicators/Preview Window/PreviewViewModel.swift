//
//  PreviewViewModel.swift
//  Loop
//
//  Created by Kai Azim on 2025-11-25.
//

import Defaults
import SwiftUI

final class PreviewViewModel: ObservableObject {
    @Published var overrideCornerRadii: RectangleCornerRadii?

    init(window: Window?) {
        if #available(macOS 26.0, *), let window {
            self.overrideCornerRadii = Self.getCornerRadius(for: window)
        } else {
            self.overrideCornerRadii = nil
        }
    }

    func setWindow(to newWindow: Window?) {
        if #available(macOS 26.0, *), let newWindow {
            overrideCornerRadii = Self.getCornerRadius(for: newWindow)
        } else {
            overrideCornerRadii = nil
        }
    }

    @available(macOS 26.0, *)
    private static func getCornerRadius(for window: Window) -> RectangleCornerRadii? {
        var cornerRadii: RectangleCornerRadii? = nil

        if Defaults[.previewUseWindowCornerRadius],
           let radii = SkyLightToolBelt.getCornerRadii(windowID: window.cgWindowID) {
            cornerRadii = radii
        }

        return cornerRadii
    }
}
