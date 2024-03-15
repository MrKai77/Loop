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
    private var isLoopActive: Bool = false
    private var targetWindow: Window?
    private var screenToResizeOn: NSScreen?

    private var flagsChangedEventMonitor: EventMonitor?
    private var mouseMovedEventMonitor: EventMonitor?
    private var keyDownEventMonitor: EventMonitor?
    private var middleClickMonitor: EventMonitor?
    private var lastTriggerKeyClick: Date = Date.now

    @Published var currentAction: WindowAction = .init(.noAction)
    private var initialMousePosition: CGPoint = CGPoint()
    private var angleToMouse: Angle = Angle(degrees: 0)
    private var distanceToMouse: CGFloat = 0

    private var triggerDelayTimer: Timer? {
        willSet {
            triggerDelayTimer?.invalidate()
        }
    }
    private var radialMenuDelayTimer: Timer? {
        willSet {
            radialMenuDelayTimer?.invalidate()
        }
    }

    func startObservingKeys() {
        self.flagsChangedEventMonitor = NSEventMonitor(
            scope: .global,
            eventMask: .flagsChanged,
            handler: handleLoopKeypress(_:)
        )

        self.mouseMovedEventMonitor = NSEventMonitor(
            scope: .global,
            eventMask: [.mouseMoved, .otherMouseDragged],
            handler: mouseMoved(_:)
        )

        self.middleClickMonitor = CGEventMonitor(
            eventMask: [.otherMouseDragged, .otherMouseUp],
            callback: handleMiddleClick(cgEvent:)
        )

        self.keyDownEventMonitor = NSEventMonitor(
            scope: .global,
            eventMask: .keyDown
        ) { _ in
            if Defaults[.doubleClickToTrigger] &&
                abs(self.lastTriggerKeyClick.timeIntervalSinceNow) < NSEvent.doubleClickInterval {
                self.lastTriggerKeyClick = Date.distantPast
            }
        }

        Notification.Name.forceCloseLoop.onRecieve { _ in
            self.closeLoop(forceClose: true)
        }

        Notification.Name.updateBackendDirection.onRecieve { notification in
            if let action = notification.userInfo?["action"] as? WindowAction {
                self.changeAction(action)
            }
        }

        self.flagsChangedEventMonitor!.start()
        self.middleClickMonitor!.start()
        self.keyDownEventMonitor!.start()
    }

    private func mouseMoved(_ event: NSEvent) {
        guard self.isLoopActive else { return }
        keybindMonitor.canPassthroughSpecialEvents = false

        let noActionDistance: CGFloat = 10

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

        var resizeDirection: WindowDirection = .noAction

        // If mouse over 50 points away, select half or quarter positions
        if distanceToMouse > pow(50 - Defaults[.radialMenuThickness], 2) {
            switch Int((angleToMouse.normalized().degrees + 22.5) / 45) {
            case 0, 8: resizeDirection = .cycleRight
            case 1:    resizeDirection = .bottomRightQuarter
            case 2:    resizeDirection = .cycleBottom
            case 3:    resizeDirection = .bottomLeftQuarter
            case 4:    resizeDirection = .cycleLeft
            case 5:    resizeDirection = .topLeftQuarter
            case 6:    resizeDirection = .cycleTop
            case 7:    resizeDirection = .topRightQuarter
            default:   resizeDirection = .noAction
            }
        } else if distanceToMouse < pow(noActionDistance, 2) {
            resizeDirection = .noAction
        } else {
            resizeDirection = .maximize
        }

        if resizeDirection != self.currentAction.direction.base {
            changeAction(.init(resizeDirection))
        }
    }

    private func performHapticFeedback() {
        if Defaults[.hapticFeedback] {
            NSHapticFeedbackManager.defaultPerformer.perform(
                NSHapticFeedbackManager.FeedbackPattern.alignment,
                performanceTime: NSHapticFeedbackManager.PerformanceTime.now
            )
        }
    }

    private func changeAction(_ action: WindowAction) {
        guard
            self.currentAction != action,
            self.isLoopActive,
            let currentScreen = self.screenToResizeOn
        else {
            return
        }

        var newAction = action

        if newAction.direction.isPresetCyclable {
            newAction = .init(newAction.direction.nextCyclingDirection(from: self.currentAction.direction))
        }

        if newAction.direction == .cycle {
            if let cycle = action.cycle {
                var nextIndex = (cycle.firstIndex(of: self.currentAction) ?? -1) + 1
                if nextIndex >= cycle.count {
                    nextIndex = 0
                }
                newAction = cycle[nextIndex]
            } else {
                return
            }
        }

        if newAction.direction.willChangeScreen {
            var newScreen: NSScreen = currentScreen

            if newAction.direction == .nextScreen,
               let nextScreen = ScreenManager.nextScreen(from: currentScreen) {
                newScreen = nextScreen
            }

            if newAction.direction == .previousScreen,
               let previousScreen = ScreenManager.previousScreen(from: currentScreen) {
                newScreen = previousScreen
            }

            if self.currentAction.direction == .noAction {
                if let targetWindow = targetWindow {
                    self.currentAction = WindowRecords.getLastAction(for: targetWindow, offset: 0)
                }

                if self.currentAction.direction == .noAction {
                    self.currentAction.direction = .maximize
                }
            }

            self.screenToResizeOn = newScreen
            self.previewController.setScreen(to: newScreen)

            // This is only needed because if preview window is moved onto a new screen, it needs to receive a window action
            DispatchQueue.main.async {
                Notification.Name.updateUIDirection.post(userInfo: ["action": self.currentAction])
            }

            if action.direction.isPresetCyclable || action.direction == .cycle {
                self.currentAction = newAction
                self.changeAction(action)
            } else {
                if let screenToResizeOn = self.screenToResizeOn,
                   !Defaults[.previewVisibility] {
                    performHapticFeedback()
                    WindowEngine.resize(
                        self.targetWindow!,
                        to: self.currentAction,
                        on: screenToResizeOn,
                        supressAnimations: true
                    )
                }
            }

            print("Screen changed: \(newScreen.localizedName)")

            return
        }

        performHapticFeedback()

        if newAction != currentAction {
            self.currentAction = newAction

            if Defaults[.hideUntilDirectionIsChosen] {
                self.openWindows()
            }

            DispatchQueue.main.async {
                Notification.Name.updateUIDirection.post(userInfo: ["action": self.currentAction])

                if let screenToResizeOn = self.screenToResizeOn,
                   !Defaults[.previewVisibility] {
                    WindowEngine.resize(
                        self.targetWindow!,
                        to: self.currentAction,
                        on: screenToResizeOn,
                        supressAnimations: true
                    )
                }
            }

            print("Window action changed: \(self.currentAction.direction)")
        }
    }

    func handleMiddleClick(cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        if let event = NSEvent(cgEvent: cgEvent), event.buttonNumber == 2, Defaults[.middleClickTriggersLoop] {
            if event.type == .otherMouseDragged && !self.isLoopActive {
                self.openLoop()
            }

            if event.type == .otherMouseUp && self.isLoopActive {
                self.closeLoop()
            }
        }
        return Unmanaged.passRetained(cgEvent)
    }

    private func handleTriggerDelay() {
        if self.triggerDelayTimer == nil {
            self.triggerDelayTimer = Timer.scheduledTimer(
                withTimeInterval: Double(Defaults[.triggerDelay]),
                repeats: false
            ) { _ in
                self.openLoop()
            }
        }
    }

    private func handleDoubleClickToTrigger(_ useTriggerDelay: Bool) {
        if abs(self.lastTriggerKeyClick.timeIntervalSinceNow) < NSEvent.doubleClickInterval {
            if useTriggerDelay {
                self.handleTriggerDelay()
            } else {
                self.openLoop()
            }
        }
    }

    private func handleLoopKeypress(_ event: NSEvent) {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.capsLock) {
            self.closeLoop(forceClose: true)
        }

        self.triggerDelayTimer = nil
        processModifiers(event)

        if Defaults[.triggerKey].isSubset(of: self.currentlyPressedModifiers) {
            let useTriggerDelay = Defaults[.triggerDelay] > 0.1
            let useDoubleClickTrigger = Defaults[.doubleClickToTrigger]

            if useDoubleClickTrigger {
                guard currentlyPressedModifiers.sorted() == Defaults[.triggerKey].sorted() else { return }
                handleDoubleClickToTrigger(useTriggerDelay)
            } else if useTriggerDelay {
                self.handleTriggerDelay()
            } else {
                self.openLoop()
            }
            self.lastTriggerKeyClick = Date.now
        } else {
            if self.isLoopActive {
                self.closeLoop()
            }
        }
    }

    private func processModifiers(_ event: NSEvent) {
        if self.currentlyPressedModifiers.contains(event.keyCode) {
            self.currentlyPressedModifiers.remove(event.keyCode)
        } else if event.modifierFlags.rawValue == 256 {
            self.currentlyPressedModifiers = []
        } else {
            self.currentlyPressedModifiers.insert(event.keyCode)
        }
    }

    private func openLoop() {
        guard self.isLoopActive == false else { return }

        self.currentAction = .init(.noAction)
        self.targetWindow = nil

        // Ensure accessibility access
        guard PermissionsManager.Accessibility.getStatus() else { return }

        self.targetWindow = WindowEngine.getTargetWindow()
        guard self.targetWindow != nil else { return }
        guard self.targetWindow!.isAppExcluded != true else { return }

        self.initialMousePosition = NSEvent.mouseLocation
        self.screenToResizeOn = NSScreen.screenWithMouse

        if !Defaults[.disableCursorInteraction] {
            self.mouseMovedEventMonitor!.start()
        }

        if !Defaults[.hideUntilDirectionIsChosen] {
            self.openWindows()
        }

        self.keybindMonitor.start()

        isLoopActive = true
    }

    private func closeLoop(forceClose: Bool = false) {
        self.triggerDelayTimer = nil
        self.closeWindows()

        self.keybindMonitor.stop()
        self.mouseMovedEventMonitor!.stop()

        self.currentlyPressedModifiers = []

        if self.targetWindow != nil,
            self.screenToResizeOn != nil,
            forceClose == false,
            self.currentAction.direction != .noAction,
            self.isLoopActive {

            if let screenToResizeOn = self.screenToResizeOn,
               Defaults[.previewVisibility] {

                WindowEngine.resize(
                    self.targetWindow!,
                    to: self.currentAction,
                    on: screenToResizeOn
                )
            }

            // This rotates the menubar icon
            Notification.Name.didLoop.post()

            // Icon stuff
            Defaults[.timesLooped] += 1
            IconManager.checkIfUnlockedNewIcon()
        } else {
            if self.targetWindow == nil && isLoopActive {
                NSSound.beep()
            }
        }

        isLoopActive = false
    }

    private func openWindows() {
        if Defaults[.previewVisibility] == true && self.targetWindow != nil {
            self.previewController.open(screen: self.screenToResizeOn!, window: targetWindow)
        }

        let useRadialMenuDelay = Defaults[.radialMenuDelay] > 0.1

        if useRadialMenuDelay {
            self.radialMenuDelayTimer = Timer.scheduledTimer(
                withTimeInterval: Defaults[.radialMenuDelay],
                repeats: false
            ) { _ in
                self.radialMenuController.open(
                    position: self.initialMousePosition,
                    frontmostWindow: self.targetWindow,
                    startingAction: self.currentAction
                )
            }
        } else {
            self.radialMenuController.open(
                position: self.initialMousePosition,
                frontmostWindow: self.targetWindow
            )
        }
    }

    private func closeWindows() {
        self.radialMenuDelayTimer = nil
        self.radialMenuController.close()
        self.previewController.close()
    }
}
