//
//  LoopManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-15.
//

import SwiftUI
import Defaults

class LoopManager: ObservableObject {

    private let accessibilityAccessManager = PermissionsManager()
    private let keybindMonitor = KeybindMonitor.shared

    private let radialMenuController = RadialMenuController()
    private let previewController = PreviewController()

    private var currentlyPressedModifiers: Set<CGKeyCode> = []
    private var isLoopShown: Bool = false
    private var frontmostWindow: Window?
    private var screenWithMouse: NSScreen?

    private var flagsChangedEventMonitor: EventMonitor?
    private var mouseMovedEventMonitor: EventMonitor?
    private var keyDownEventMonitor: EventMonitor?
    private var middleClickMonitor: EventMonitor?
    private var triggerDelayTimer: DispatchSourceTimer?
    private var lastTriggerKeyClick: Date = Date.now

    @Published var currentResizeDirection: WindowDirection = .noAction
    private var initialMousePosition: CGPoint = CGPoint()
    private var angleToMouse: Angle = Angle(degrees: 0)
    private var distanceToMouse: CGFloat = 0

    func startObservingKeys() {
        self.flagsChangedEventMonitor = NSEventMonitor(scope: .global, eventMask: .flagsChanged, handler: handleLoopKeypress(_:))
        self.flagsChangedEventMonitor!.start()

        self.mouseMovedEventMonitor = NSEventMonitor(scope: .global, eventMask: .mouseMoved, handler: mouseMoved(_:))

        self.middleClickMonitor = CGEventMonitor(eventMask: [.otherMouseDragged, .otherMouseUp], callback: handleMiddleClick(cgEvent:))
        self.middleClickMonitor!.start()

        self.keyDownEventMonitor = NSEventMonitor(scope: .global, eventMask: .keyDown) { _ in
            if Defaults[.doubleClickToTrigger] &&
                abs(self.lastTriggerKeyClick.timeIntervalSinceNow) < NSEvent.doubleClickInterval {
                self.lastTriggerKeyClick = Date.distantPast
            }
        }
        self.keyDownEventMonitor!.start()

        Notification.Name.forceCloseLoop.onRecieve { _ in
            self.closeLoop(forceClose: true)
        }
    }

    private func mouseMoved(_ event: NSEvent) {
        let noActionDistance: CGFloat = 8

        let currentMouseLocation = NSEvent.mouseLocation
        let mouseAngle = Angle(radians: initialMousePosition.angle(to: currentMouseLocation))
        let mouseDistance = initialMousePosition.distanceSquared(to: currentMouseLocation)

        // Return if the mouse didn't move
        if (mouseAngle == angleToMouse) && (mouseDistance == distanceToMouse) {
            return
        }

        // Get angle & distance to mouse
        self.angleToMouse = mouseAngle
        self.distanceToMouse = mouseDistance

        let previousResizeDirection = currentResizeDirection

        // If mouse over 50 points away, select half or quarter positions
        if distanceToMouse > pow(50 - Defaults[.radialMenuThickness], 2) {
            switch Int((angleToMouse.normalized().degrees + 22.5) / 45) {
            case 0, 8: currentResizeDirection = .cycleRight
            case 1:    currentResizeDirection = .bottomRightQuarter
            case 2:    currentResizeDirection = .cycleBottom
            case 3:    currentResizeDirection = .bottomLeftQuarter
            case 4:    currentResizeDirection = .cycleLeft
            case 5:    currentResizeDirection = .topLeftQuarter
            case 6:    currentResizeDirection = .cycleTop
            case 7:    currentResizeDirection = .topRightQuarter
            default:   currentResizeDirection = .noAction
            }
        } else if distanceToMouse < pow(noActionDistance, 2) {
            currentResizeDirection = .noAction
        } else {
            currentResizeDirection = .maximize
        }

        if currentResizeDirection.cyclable {
            self.currentResizeDirection = currentResizeDirection.nextCyclingDirection(from: self.currentResizeDirection)
        }

        if currentResizeDirection != previousResizeDirection {
            Notification.Name.directionChanged.post(userInfo: ["direction": currentResizeDirection])

            NSHapticFeedbackManager.defaultPerformer.perform(
                NSHapticFeedbackManager.FeedbackPattern.alignment,
                performanceTime: NSHapticFeedbackManager.PerformanceTime.now
            )
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

            if useDoubleClickTrigger &&
               abs(self.lastTriggerKeyClick.timeIntervalSinceNow) < NSEvent.doubleClickInterval {
                if useTriggerDelay {
                    if self.triggerDelayTimer == nil {
                        self.startTriggerDelayTimer(seconds: Defaults[.triggerDelay]) {
                            self.openLoop()
                        }
                    }
                } else {
                    self.openLoop()
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

        self.currentResizeDirection = .noAction
        self.frontmostWindow = nil

        // Loop will only open if accessibility access has been granted
        if PermissionsManager.Accessibility.getStatus() {
            self.frontmostWindow = WindowEngine.frontmostWindow
            self.initialMousePosition = NSEvent.mouseLocation
            self.screenWithMouse = NSScreen.screenWithMouse
            self.mouseMovedEventMonitor!.start()

            if Defaults[.previewVisibility] == true && self.frontmostWindow != nil {
                self.previewController.open(screen: self.screenWithMouse!, window: frontmostWindow)
            }
            self.radialMenuController.open(frontmostWindow: frontmostWindow)
            self.keybindMonitor.start()

            isLoopShown = true
        }
    }

    private func closeLoop(forceClose: Bool = false) {
        self.cancelTriggerDelayTimer()
        self.radialMenuController.close()
        self.previewController.close()

        self.keybindMonitor.resetPressedKeys()
        self.keybindMonitor.stop()
        self.mouseMovedEventMonitor!.stop()

        if self.frontmostWindow != nil &&
            self.screenWithMouse != nil &&
            forceClose == false &&
            self.currentResizeDirection != .noAction &&
            self.isLoopShown {

            WindowEngine.resize(self.frontmostWindow!, to: self.currentResizeDirection, self.screenWithMouse!)

            // This rotates the menubar icon
            Notification.Name.didLoop.post()

            // Icon stuff
            Defaults[.timesLooped] += 1
            IconManager.checkIfUnlockedNewIcon()
        } else {
            if self.frontmostWindow == nil && isLoopShown {
                NSSound.beep()
            }
        }

        isLoopShown = false
    }
}
