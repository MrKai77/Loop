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

    private var eventMonitor: NSEventMonitor?
    private var triggerDelayTimer: DispatchSourceTimer?
    private var lastTriggerKeyClick: Date = Date.now

    func startObservingKeys() {
        self.eventMonitor = NSEventMonitor(scope: .global, eventMask: .flagsChanged) { event in
            self.handleLoopKeypress(event)
        }
        self.eventMonitor!.start()

        Notification.Name.directionChanged.onRecieve { notification in
            self.currentWindowDirectionChanged(notification)
        }

        Notification.Name.forceCloseLoop.onRecieve { _ in
            self.closeLoop(forceClose: true)
        }
    }

    private func cancelTriggerDelayTimer() {
        self.triggerDelayTimer?.cancel()
        self.triggerDelayTimer = nil
    }

    private func startTriggerDelayTimer(seconds: Float, handler: @escaping () -> Void) {
        self.triggerDelayTimer = DispatchSource.makeTimerSource(queue: .main)
        self.triggerDelayTimer!.schedule(deadline: .now() + .milliseconds(Int(seconds*1000)))
        self.triggerDelayTimer!.setEventHandler {
            handler()
            self.triggerDelayTimer = nil
        }
        self.triggerDelayTimer!.resume()
    }

    private func currentWindowDirectionChanged(_ notification: Notification) {
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

    private func handleLoopKeypress(_ event: NSEvent) {
        if event.keyCode == Defaults[.triggerKey].keycode {

            let useTriggerDelay = Defaults[.triggerDelay] > 0.1
            let useDoubleClickTrigger = Defaults[.doubleClickToTrigger]

            if event.modifierFlags.rawValue ==  256 {
                if useTriggerDelay {
                    self.cancelTriggerDelayTimer()
                }
                self.closeLoop()
            } else {
                if useDoubleClickTrigger {
                    if abs(self.lastTriggerKeyClick.timeIntervalSinceNow) < NSEvent.doubleClickInterval {
                        if useTriggerDelay {
                            if self.triggerDelayTimer == nil {
                                self.startTriggerDelayTimer(seconds: Defaults[.triggerDelay]) {
                                    self.openLoop()
                                }
                            }
                        } else {
                            self.openLoop()
                        }
                    }
                    self.lastTriggerKeyClick = Date.now
                } else if useTriggerDelay {
                    if self.triggerDelayTimer == nil {
                        self.startTriggerDelayTimer(seconds: Defaults[.triggerDelay]) {
                            self.openLoop()
                        }
                    }
                } else {
                    self.openLoop()
                }
            }
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

            Notification.Name.didLoop.post()

            Defaults[.timesLooped] += 1
            iconManager.checkIfUnlockedNewIcon()
        } else {
            if self.frontmostWindow == nil {
                NSSound.beep()
            }
        }
    }
}
