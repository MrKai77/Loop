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

    private let radialMenuController = RadialMenuController()
    private let previewController = PreviewController()

    private var currentResizingDirection: WindowDirection = .noAction
    private var currentlyPressedModifiers: Set<CGKeyCode> = []
    private var isLoopShown: Bool = false
    private var frontmostWindow: Window?
    private var screenWithMouse: NSScreen?

    private var flagsChangedEventMonitor: EventMonitor?
    private var keyDownEventMonitor: EventMonitor?
    private var middleClickMonitor: EventMonitor?
    private var scrollEventMonitor: EventMonitor?
    private var triggerDelayTimer: DispatchSourceTimer?
    private var lastTriggerKeyClick: Date = Date.now

    func startObservingKeys() {
        self.flagsChangedEventMonitor = NSEventMonitor(scope: .global, eventMask: .flagsChanged) { event in
            self.handleLoopKeypress(event)
        }
        self.flagsChangedEventMonitor!.start()

        self.keyDownEventMonitor = NSEventMonitor(scope: .global, eventMask: .keyDown) { _ in
            if Defaults[.doubleClickToTrigger] &&
                abs(self.lastTriggerKeyClick.timeIntervalSinceNow) < NSEvent.doubleClickInterval {
                self.lastTriggerKeyClick = Date.distantPast
            }
        }
        self.keyDownEventMonitor!.start()

        self.middleClickMonitor = CGEventMonitor(
            eventMask: [.otherMouseDragged, .otherMouseUp],
            callback: handleMiddleClick(cgEvent:)
        )
        self.middleClickMonitor?.start()

        self.scrollEventMonitor = CGEventMonitor(eventMask: [.scrollWheel]) { cgEvent in
            if cgEvent.type == .scrollWheel, self.isLoopShown, let event = NSEvent(cgEvent: cgEvent) {

                if Defaults[.preferMinimizeWithScrollDown] {
                    if event.deltaY > 1 && self.currentResizingDirection != .minimize {
                        Notification.Name.directionChanged.post(userInfo: ["direction": WindowDirection.minimize])
                    }

                    if event.deltaY < -1 && self.currentResizingDirection == .minimize {
                        Notification.Name.directionChanged.post(userInfo: ["direction": WindowDirection.noAction])
                    }
                } else {
                    if event.deltaY > 1 && self.currentResizingDirection != .hide {
                        Notification.Name.directionChanged.post(userInfo: ["direction": WindowDirection.hide])
                    }

                    if event.deltaY < -1 && self.currentResizingDirection == .hide {
                        Notification.Name.directionChanged.post(userInfo: ["direction": WindowDirection.noAction])
                    }
                }

                return nil
            }
            return Unmanaged.passRetained(cgEvent)
        }

        Notification.Name.directionChanged.onRecieve { notification in
            self.currentWindowDirectionChanged(notification)
        }

        Notification.Name.forceCloseLoop.onRecieve { _ in
            self.closeLoop(forceClose: true)
        }
    }

    func handleMiddleClick(cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        if let event = NSEvent(cgEvent: cgEvent), event.buttonNumber == 2, Defaults[.middleClickTriggersLoop] {
            if event.type == .otherMouseDragged && !self.isLoopShown {
                self.openLoop()
            }

            if event.type == .otherMouseUp && self.isLoopShown {
                self.closeLoop()
            }
        }
        return Unmanaged.passRetained(cgEvent)
    }

    private func cancelTriggerDelayTimer() {
        self.triggerDelayTimer?.cancel()
        self.triggerDelayTimer = nil
    }

    private func startTriggerDelayTimer(seconds: Float, handler: @escaping () -> Void) {
        self.triggerDelayTimer = DispatchSource.makeTimerSource(queue: .main)
        self.triggerDelayTimer!.schedule(deadline: .now() + .milliseconds(Int(seconds * 1000)))
        self.triggerDelayTimer!.setEventHandler {
            handler()
            self.triggerDelayTimer = nil
        }
        self.triggerDelayTimer!.resume()
    }

    private func currentWindowDirectionChanged(_ notification: Notification) {
        if let newDirection = notification.userInfo?["direction"] as? WindowDirection {
            if newDirection.cyclable {
                self.currentResizingDirection = newDirection.nextCyclingDirection(from: self.currentResizingDirection)
                Notification.Name.directionChanged.post(userInfo: ["direction": self.currentResizingDirection])
                return
            }

            self.currentResizingDirection = newDirection

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
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.capsLock) {
            self.closeLoop(forceClose: true)
            return
        }

        if self.currentlyPressedModifiers.contains(event.keyCode) {
            self.currentlyPressedModifiers.remove(event.keyCode)
        } else if event.modifierFlags.rawValue == 256 {
            self.currentlyPressedModifiers = []
        } else {
            self.currentlyPressedModifiers.insert(event.keyCode)
        }

        // Why sort the set? I have no idea. But it works much more reliably when sorted!
        if self.currentlyPressedModifiers.sorted().contains(Defaults[.triggerKey].sorted()) {
            let useTriggerDelay = Defaults[.triggerDelay] > 0.1
            let useDoubleClickTrigger = Defaults[.doubleClickToTrigger]

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
            } else if useTriggerDelay {
                if self.triggerDelayTimer == nil {
                    self.startTriggerDelayTimer(seconds: Defaults[.triggerDelay]) {
                        self.openLoop()
                    }
                }
            } else {
                self.openLoop()
            }
            self.lastTriggerKeyClick = Date.now
        } else {
            if self.isLoopShown {
                self.closeLoop()
            }
        }
    }

    private func openLoop() {
        guard self.isLoopShown == false else { return }

        self.currentResizingDirection = .noAction
        self.frontmostWindow = nil

        // Loop will only open if accessibility access has been granted
        if PermissionsManager.Accessibility.getStatus() {
            self.frontmostWindow = WindowEngine.frontmostWindow
            self.screenWithMouse = NSScreen.screenWithMouse

            if Defaults[.previewVisibility] == true && self.frontmostWindow != nil {
                self.previewController.open(screen: self.screenWithMouse!, window: frontmostWindow)
            }
            self.radialMenuController.open(frontmostWindow: frontmostWindow)
            self.keybindMonitor.start()
            self.scrollEventMonitor?.start()

            isLoopShown = true
        }
    }

    private func closeLoop(forceClose: Bool = false) {
        self.cancelTriggerDelayTimer()
        self.radialMenuController.close()
        self.previewController.close()

        self.keybindMonitor.resetPressedKeys()
        self.keybindMonitor.stop()
        self.scrollEventMonitor?.stop()

        if self.frontmostWindow != nil &&
            self.screenWithMouse != nil &&
            forceClose == false &&
            self.currentResizingDirection != .noAction &&
            self.isLoopShown {

            isLoopShown = false

            WindowEngine.resize(self.frontmostWindow!, to: self.currentResizingDirection, self.screenWithMouse!)
            Notification.Name.didLoop.post()
            Defaults[.timesLooped] += 1
            IconManager.checkIfUnlockedNewIcon()
        } else {
            if self.frontmostWindow == nil && isLoopShown {
                NSSound.beep()
            }
            isLoopShown = false
        }
    }
}
