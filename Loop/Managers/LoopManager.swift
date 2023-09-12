//
//  LoopManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-15.
//

import SwiftUI
import Defaults

class LoopManager {

    private let accessibilityAccessManager = PermissionsManager()
    private let keybindMonitor = KeybindMonitor.shared
    private let iconManager = IconManager()

    private let radialMenuController = RadialMenuController()
    private let previewController = PreviewController()

    private var currentResizingDirection: WindowDirection = .noAction
    private var isLoopShown: Bool = false
    private var frontmostWindow: Window?
    private var screenWithMouse: NSScreen?

    private var timer: DispatchSourceTimer?    // Used when user has configured a trigger delay

    func startObservingKeys() {
        NSEvent.addGlobalMonitorForEvents(matching: NSEvent.EventTypeMask.flagsChanged) { event -> Void in
            if event.keyCode == Defaults[.triggerKey] {
                if event.modifierFlags.rawValue == 256 {
                    if self.timer != nil {
                        self.timer?.cancel()
                        self.timer = nil
                    } else {
                        self.closeLoop()
                    }
                } else {
                    if self.timer == nil {
                        self.timer = DispatchSource.makeTimerSource(queue: .main)
                        self.timer!.schedule(deadline: .now() + .milliseconds(Int(Defaults[.triggerDelay]*1000)))
                        self.timer!.setEventHandler {
                            self.openLoop()
                            self.timer = nil
                        }
                        self.timer!.resume()
                    }
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
        if let direction = notification.userInfo?["direction"] as? WindowDirection {
            currentResizingDirection = direction

            // Haptic feedback on the trackpad
            if self.isLoopShown {
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
        if PermissionsManager.Accessibility.getStatus() {
            self.frontmostWindow = WindowEngine.frontmostWindow
            self.screenWithMouse = NSScreen.screenWithMouse

            if Defaults[.previewVisibility] == true && frontmostWindow != nil {
                previewController.show(screen: self.screenWithMouse!)
            }
            radialMenuController.show(frontmostWindow: frontmostWindow)
            keybindMonitor.start()

            isLoopShown = true
        }
    }

    private func closeLoop(forceClose: Bool = false) {
        var willResizeWindow: Bool = false

        radialMenuController.close()
        previewController.close()

        keybindMonitor.resetPressedKeys()
        keybindMonitor.stop()

        if self.frontmostWindow != nil &&
            self.screenWithMouse != nil &&
            forceClose == false &&
            self.isLoopShown == true &&
            self.currentResizingDirection != .noAction {
            willResizeWindow = true
        }

        isLoopShown = false

        if willResizeWindow {
            WindowEngine.resize(self.frontmostWindow!, to: self.currentResizingDirection, self.screenWithMouse!)

            NotificationCenter.default.post(
                name: Notification.Name.finishedLooping,
                object: nil
            )

            Defaults[.timesLooped] += 1
            iconManager.checkIfUnlockedNewIcon()
        } else {
            if self.frontmostWindow == nil {
                NSSound.beep()
            }
        }
    }
}
