//
//  LoopManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-15.
//

import Defaults
import SwiftUI

class LoopManager: ObservableObject {
    // Size Adjustment
    static var sidesToAdjust: Edge.Set?
    static var lastTargetFrame: CGRect = .zero
    static var canAdjustSize: Bool = true

    private let keybindMonitor = KeybindMonitor.shared

    private let radialMenuController = RadialMenuController()
    private let previewController = PreviewController()

    private var currentlyPressedModifiers: Set<CGKeyCode> = []
    private var isLoopActive: Bool = false
    private var targetWindow: Window?
    private var screenToResizeOn: NSScreen?

    private var flagsChangedEventMonitor: EventMonitor?
    private var mouseMovedEventMonitor: EventMonitor?
    private var middleClickMonitor: EventMonitor?
    private var lastTriggerKeyClick: Date = .now

    @Published var currentAction: WindowAction = .init(.noAction)
    private var initialMousePosition: CGPoint = .init()
    private var angleToMouse: Angle = .init(degrees: 0)
    private var distanceToMouse: CGFloat = 0

    private var triggerDelayTimer: Timer? {
        willSet {
            triggerDelayTimer?.invalidate()
        }
    }

    func start() {
        Notification.Name.forceCloseLoop.onReceive { _ in
            self.closeLoop(forceClose: true)
        }

        Notification.Name.updateBackendDirection.onReceive { notification in
            if let action = notification.userInfo?["action"] as? WindowAction {
                self.changeAction(action)
            }
        }

        mouseMovedEventMonitor = NSEventMonitor(
            scope: .all,
            eventMask: [.mouseMoved, .otherMouseDragged],
            handler: mouseMoved(_:)
        )

        middleClickMonitor = CGEventMonitor(
            eventMask: [.otherMouseDragged, .otherMouseUp],
            callback: handleMiddleClick(cgEvent:)
        )

        setFlagsObservers(scope: .all)
        middleClickMonitor?.start()
    }

    // This is called when setting the trigger key, so that there aren't conflicting event monitors
    func setFlagsObservers(scope: NSEventMonitor.Scope = .all) {
        flagsChangedEventMonitor?.stop()

        flagsChangedEventMonitor = NSEventMonitor(
            scope: scope,
            eventMask: .flagsChanged,
            handler: handleLoopKeypress(_:)
        )

        flagsChangedEventMonitor?.start()
    }

    private func mouseMoved(_: NSEvent) {
        guard isLoopActive else { return }
        keybindMonitor.canPassthroughSpecialEvents = false

        let noActionDistance: CGFloat = 10

        let currentMouseLocation = NSEvent.mouseLocation
        let mouseAngle = Angle(radians: initialMousePosition.angle(to: currentMouseLocation))
        let mouseDistance = initialMousePosition.distanceSquared(to: currentMouseLocation)

        // Return if the mouse didn't move
        if mouseAngle == angleToMouse, mouseDistance == distanceToMouse {
            return
        }

        // Get angle & distance to mouse
        angleToMouse = mouseAngle
        distanceToMouse = mouseDistance

        var resizeDirection: WindowDirection = .noAction

        // If mouse over 50 points away, select half or quarter positions
        if distanceToMouse > pow(50 - Defaults[.radialMenuThickness], 2) {
            switch Int((angleToMouse.normalized().degrees + 22.5) / 45) {
            case 0, 8:
                resizeDirection = .rightHalf
            case 1:
                resizeDirection = .bottomRightQuarter
            case 2:
                resizeDirection = .bottomHalf
            case 3:
                resizeDirection = .bottomLeftQuarter
            case 4:
                resizeDirection = .leftHalf
            case 5:
                resizeDirection = .topLeftQuarter
            case 6:
                resizeDirection = .topHalf
            case 7:
                resizeDirection = .topRightQuarter
            default:
                resizeDirection = .noAction
            }
        } else if distanceToMouse < pow(noActionDistance, 2) {
            resizeDirection = .noAction
        } else {
            resizeDirection = .maximize
        }

        if resizeDirection != currentAction.direction {
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

    private func getNextCycleAction(_ action: WindowAction) -> WindowAction {
        guard let currentCycle = action.cycle else {
            return action
        }

        var nextIndex = 0

        if !currentCycle.contains(currentAction),
           let window = targetWindow,
           let latestRecord = WindowRecords.getCurrentAction(for: window) {
            // We "preserve" the cycle index based on the last record
            nextIndex = (currentCycle.firstIndex(of: latestRecord) ?? -1) + 1

        } else if currentAction.direction == .custom {
            // We need to check if *all* the characteristics of the action are the same
            nextIndex = (currentCycle.firstIndex(of: currentAction) ?? -1) + 1
        } else {
            // Only check the direction, since the rest of the info is insignificant
            nextIndex = (currentCycle.firstIndex { $0.direction == currentAction.direction } ?? -1) + 1
        }

        if nextIndex >= currentCycle.count {
            nextIndex = 0
        }

        return currentCycle[nextIndex]
    }

    private func changeAction(_ action: WindowAction, triggeredFromScreenChange: Bool = false) {
        guard
            currentAction != action || action.willManipulateExistingWindowFrame,
            isLoopActive,
            let currentScreen = screenToResizeOn
        else {
            return
        }

        var newAction = action

        if newAction.direction == .cycle {
            newAction = getNextCycleAction(action)

            // Prevents an endless loop of cycling screens
            if triggeredFromScreenChange, newAction.direction.willChangeScreen {
                performHapticFeedback()
                return
            }
        }

        if newAction.direction.willChangeScreen {
            var newScreen = currentScreen

            if newAction.direction == .nextScreen,
               let nextScreen = ScreenManager.nextScreen(from: currentScreen) {
                newScreen = nextScreen
            }

            if newAction.direction == .previousScreen,
               let previousScreen = ScreenManager.previousScreen(from: currentScreen) {
                newScreen = previousScreen
            }

            if currentAction.direction == .noAction {
                currentAction = .init(.center)
            }

            screenToResizeOn = newScreen
            previewController.setScreen(to: newScreen)

            // This is only needed because if preview window is moved
            // onto a new screen, it needs to receive a window action
            DispatchQueue.main.async {
                Notification.Name.updateUIDirection.post(userInfo: ["action": self.currentAction])
            }

            if action.direction == .cycle {
                currentAction = newAction
                changeAction(action, triggeredFromScreenChange: true)
            } else {
                if let screenToResizeOn,
                   let window = targetWindow,
                   !Defaults[.previewVisibility] {
                    performHapticFeedback()
                    WindowEngine.resize(
                        window,
                        to: currentAction,
                        on: screenToResizeOn
                    )
                }
            }

            print("Screen changed: \(newScreen.localizedName)")

            return
        }

        performHapticFeedback()

        if newAction != currentAction || newAction.willManipulateExistingWindowFrame {
            currentAction = newAction

            if Defaults[.hideUntilDirectionIsChosen] {
                openWindows()
            }

            DispatchQueue.main.async {
                Notification.Name.updateUIDirection.post(userInfo: ["action": self.currentAction])

                if let screenToResizeOn = self.screenToResizeOn,
                   let window = self.targetWindow,
                   !Defaults[.previewVisibility] {
                    WindowEngine.resize(
                        window,
                        to: self.currentAction,
                        on: screenToResizeOn
                    )
                }
            }

            print("Window action changed: \(currentAction.direction)")
        }
    }

    func handleMiddleClick(cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        if let event = NSEvent(cgEvent: cgEvent), event.buttonNumber == 2, Defaults[.middleClickTriggersLoop] {
            if event.type == .otherMouseDragged, !isLoopActive {
                openLoop()
            }

            if event.type == .otherMouseUp, isLoopActive {
                closeLoop()
            }
        }
        return Unmanaged.passUnretained(cgEvent)
    }

    private func handleTriggerDelay() {
        if triggerDelayTimer == nil {
            triggerDelayTimer = Timer.scheduledTimer(
                withTimeInterval: Double(Defaults[.triggerDelay]),
                repeats: false
            ) { _ in
                self.openLoop()
            }
        }
    }

    private func handleDoubleClickToTrigger(_ useTriggerDelay: Bool) {
        if abs(lastTriggerKeyClick.timeIntervalSinceNow) < NSEvent.doubleClickInterval {
            if useTriggerDelay {
                handleTriggerDelay()
            } else {
                openLoop()
            }
        }
    }

    private func handleLoopKeypress(_ event: NSEvent) {
        triggerDelayTimer = nil

        let previousModifiers = currentlyPressedModifiers
        processModifiers(event)

        let triggerKey = Defaults[.triggerKey]
        let wasKeyDown = event.type == .keyDown || currentlyPressedModifiers.count > previousModifiers.count

        if wasKeyDown, triggerKey.isSubset(of: currentlyPressedModifiers) {
            guard
                !isLoopActive,

                // This makes sure that the amount of keys being pressed is not more than the actual trigger key
                currentlyPressedModifiers.count <= triggerKey.count
            else {
                return
            }

            let useTriggerDelay = Defaults[.triggerDelay] > 0.1
            let useDoubleClickTrigger = Defaults[.doubleClickToTrigger]

            if useDoubleClickTrigger {
                guard currentlyPressedModifiers.sorted() == Defaults[.triggerKey].sorted() else { return }
                handleDoubleClickToTrigger(useTriggerDelay)
            } else if useTriggerDelay {
                handleTriggerDelay()
            } else {
                openLoop()
            }
            lastTriggerKeyClick = .now
        } else {
            closeLoop()
        }
    }

    private func processModifiers(_ event: NSEvent) {
        if event.modifierFlags.wasKeyUp {
            currentlyPressedModifiers = []
        } else if currentlyPressedModifiers.contains(event.keyCode) {
            currentlyPressedModifiers.remove(event.keyCode)
        } else {
            currentlyPressedModifiers.insert(event.keyCode)
        }

        // Backup system in case keys are pressed at the exact same time
        let flags = event.modifierFlags.convertToCGKeyCode()
        if flags.count != currentlyPressedModifiers.count {
            for key in flags where CGKeyCode.keyToImage.contains(where: { $0.key == key }) {
                if !currentlyPressedModifiers.map(\.baseModifier).contains(key) {
                    currentlyPressedModifiers.insert(key)
                }
            }
        }
    }

    private func openLoop() {
        guard isLoopActive == false else { return }

        currentAction = .init(.noAction)
        targetWindow = nil

        // Ensure accessibility access
        guard AccessibilityManager.getStatus() else { return }

        targetWindow = WindowEngine.getTargetWindow()
        guard targetWindow?.isAppExcluded != true else { return }

        initialMousePosition = NSEvent.mouseLocation
        screenToResizeOn = Defaults[.useScreenWithCursor] ? NSScreen.screenWithMouse : NSScreen.main

        if !Defaults[.disableCursorInteraction] {
            mouseMovedEventMonitor?.start()
        }

        keybindMonitor.start()
        isLoopActive = true

        Task {
            if Defaults[.processWallpaper] {
                await WallpaperProcessor.fetchLatestWallpaperColors()
            }

            if !Defaults[.hideUntilDirectionIsChosen] {
                DispatchQueue.main.async {
                    self.openWindows()
                }
            }
        }

        if let window = targetWindow {
            LoopManager.lastTargetFrame = window.frame
        }
    }

    private func closeLoop(forceClose: Bool = false) {
        guard isLoopActive == true else { return }

        triggerDelayTimer = nil
        closeWindows()

        keybindMonitor.stop()
        mouseMovedEventMonitor?.stop()

        currentlyPressedModifiers = []

        if targetWindow != nil,
           screenToResizeOn != nil,
           forceClose == false,
           currentAction.direction != .noAction,
           isLoopActive {
            if let screenToResizeOn,
               Defaults[.previewVisibility] {
                LoopManager.canAdjustSize = false
                WindowEngine.resize(
                    targetWindow!,
                    to: currentAction,
                    on: screenToResizeOn
                )
            }

            // This rotates the menubar icon
            Notification.Name.didLoop.post()

            // Icon stuff
            Defaults[.timesLooped] += 1
            IconManager.checkIfUnlockedNewIcon()
        } else {
            if targetWindow == nil, isLoopActive {
                NSSound.beep()
            }
        }

        isLoopActive = false
        LoopManager.sidesToAdjust = nil
        LoopManager.lastTargetFrame = .zero
        LoopManager.canAdjustSize = true
    }

    private func openWindows() {
        if Defaults[.previewVisibility], targetWindow != nil {
            previewController.open(
                screen: screenToResizeOn!,
                window: targetWindow,
                startingAction: currentAction
            )
        }

        if Defaults[.radialMenuVisibility] {
            radialMenuController.open(
                position: initialMousePosition,
                frontmostWindow: targetWindow,
                startingAction: currentAction
            )
        }
    }

    private func closeWindows() {
        radialMenuController.close()
        previewController.close()
    }
}
