//
//  MultitouchTargetResolver.swift
//  Loop
//
//  Created by Kai Azim on 2026-07-06.
//

import Defaults
import Scribe
import SwiftUI

@Loggable
@MainActor
final class MultitouchTargetResolver {
    /// Window most recently targeted by a repeatable gesture.
    /// Lets shrinking/growing continue after the cursor falls off the resized frame.
    private var lastRepeatableWindow: Window?
    private var hasResolvedGestureWindow = false
    private var resolvedGestureWindow: Window?

    func reset() {
        lastRepeatableWindow = nil
        resetGestureState()
    }

    func resetGestureState() {
        hasResolvedGestureWindow = false
        resolvedGestureWindow = nil
    }

    func targetWindow(for gesture: GestureBinding, allowsRapidRepeat: Bool) -> Window? {
        let window = findTargetWindow(for: gesture)
        if window == nil, allowsRapidRepeat {
            return lastRepeatableWindow
        }
        return window
    }

    func rememberRepeatableWindow(_ window: Window?, allowsRapidRepeat: Bool) {
        guard let window, allowsRapidRepeat else { return }
        lastRepeatableWindow = window
    }

    private func findTargetWindow(for gesture: GestureBinding) -> Window? {
        let cursorPosition = NSEvent.mouseLocation.flipY(screen: NSScreen.screens[0])
        let activationZone: GestureBinding.ActivationZone = gesture.fingerCount <= 2 ? .titlebar : gesture.activationZone

        if hasResolvedGestureWindow {
            return resolvedGestureWindow
        }

        guard let window = WindowUtility.windowAtPosition(cursorPosition) else {
            hasResolvedGestureWindow = true
            return nil
        }

        // 2-finger gestures are always titlebar-only to avoid system gesture conflicts.
        switch activationZone {
        case .titlebar:
            let minimumTitlebarHeight = Defaults[.gestureTitlebarHeight]
            let titlebarHeight: CGFloat = if #available(macOS 26, *) {
                if #unavailable(macOS 27),
                   let cornerRadius = SkyLightToolBelt.getCornerRadii(windowID: window.cgWindowID)?.topLeading {
                    max(2 * cornerRadius, minimumTitlebarHeight)
                } else {
                    minimumTitlebarHeight
                }
            } else {
                minimumTitlebarHeight
            }

            log.debug("Detected titlebar height of \(titlebarHeight)")

            let titlebarMinY = window.frame.minY
            let titlebarMaxY = window.frame.minY + titlebarHeight
            let isInTitlebar = cursorPosition.y >= titlebarMinY && cursorPosition.y <= titlebarMaxY
            let targetWindow = isInTitlebar ? window : nil
            resolvedGestureWindow = targetWindow
            hasResolvedGestureWindow = true
            return targetWindow

        case .anywhere:
            resolvedGestureWindow = window
            hasResolvedGestureWindow = true
            return window
        }
    }
}
