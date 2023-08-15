//
//  LoopManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-15.
//

import SwiftUI
import Defaults

class LoopManager {

    private let accessibilityAccessManager = AccessibilityAccessManager()
    private let windowEngine = WindowEngine()
    private let keybindMonitor = KeybindMonitor.shared
    private let iconManager = IconManager()

    private let radialMenuController = RadialMenuController()
    private let previewController = PreviewController()

    private var currentResizingDirection: WindowDirection = .noAction
    private var isLoopShown: Bool = false
    private var frontmostWindow: AXUIElement?

    func startObservingKeys() {
        NSEvent.addGlobalMonitorForEvents(matching: NSEvent.EventTypeMask.flagsChanged) { event -> Void in
            if event.keyCode == Defaults[.triggerKey] {
                if event.modifierFlags.rawValue == 256 {
                    self.closeLoop()
                } else {
                    self.openLoop()
                }
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(
                currentWindowDirectionChanged(
                    notification:
                )
            ),
            name: Notification.Name.directionChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(
                forceCloseLoop(
                    notification:
                )
            ),
            name: Notification.Name.forceCloseLoop,
            object: nil
        )
    }

    @objc private func currentWindowDirectionChanged(notification: Notification) {
        if let direction = notification.userInfo?["Direction"] as? WindowDirection,
           let keybind = notification.userInfo?["Keybind"] as? Bool? {
            currentResizingDirection = direction

            // Haptic feedback on the trackpad
            if self.isLoopShown && keybind == nil {
                NSHapticFeedbackManager.defaultPerformer.perform(
                    NSHapticFeedbackManager.FeedbackPattern.alignment,
                    performanceTime: NSHapticFeedbackManager.PerformanceTime.now
                )
            }
        }
    }

    @objc private func forceCloseLoop(notification: Notification) {
        if let forceClose = notification.userInfo?["forceClose"] as? Bool {
            self.closeLoop(forceClose: forceClose)
        }
    }

    private func openLoop() {
        currentResizingDirection = .noAction
        frontmostWindow = nil

        // Loop will only open if accessibility access has been granted
        if accessibilityAccessManager.checkAccessibilityAccess() {
            self.frontmostWindow = windowEngine.getFrontmostWindow()

            if Defaults[.previewVisibility] == true && frontmostWindow != nil {
                previewController.showPreview()
            }
            radialMenuController.showRadialMenu(frontmostWindow: frontmostWindow)

            keybindMonitor.start()

            isLoopShown = true
        }
    }

    private func closeLoop(forceClose: Bool = false) {
        var willResizeWindow: Bool = false

        radialMenuController.closeRadialMenu()
        previewController.closePreview()
        keybindMonitor.stop()

        if self.frontmostWindow != nil &&
            forceClose == false &&
            self.isLoopShown == true &&
            self.currentResizingDirection != .noAction {
            willResizeWindow = true
        }

        isLoopShown = false

        if willResizeWindow {
            windowEngine.resize(window: self.frontmostWindow!, direction: self.currentResizingDirection)

            Defaults[.timesLooped] += 1
            iconManager.checkIfUnlockedNewIcon()
        }
    }
}
