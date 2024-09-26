//
//  LoopManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-15.
//

import Defaults
import SwiftUI

// MARK: - LoopManager

class LoopManager: ObservableObject {
    // Size Adjustment
    static var sidesToAdjust: Edge.Set?
    static var lastTargetFrame: CGRect = .zero

    private let keybindMonitor = KeybindMonitor.shared

    private let radialMenuController = RadialMenuController()
    private let previewController = PreviewController()

    private var currentlyPressedModifiers: Set<CGKeyCode> = []
    private var isLoopActive: Bool = false
    private var lastLoopActivation: Date = .distantPast
    private var targetWindow: Window?
    private var screenToResizeOn: NSScreen?

    private var flagsChangedEventMonitor: EventMonitor?
    private var mouseMovedEventMonitor: EventMonitor?
    private var middleClickMonitor: EventMonitor?
    private var leftClickMonitor: EventMonitor?
    private var lastTriggerKeyClick: Date = .distantPast

    @Published var currentAction: WindowAction = .init(.noAction)
    private var parentCycleAction: WindowAction? = nil
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
}

// MARK: - Opening/Closing Loop

private extension LoopManager {
    func openLoop() {
        guard
            isLoopActive == false,
            AccessibilityManager.getStatus()
        else {
            return
        }

        targetWindow = WindowEngine.getTargetWindow()
        guard
            targetWindow?.isAppExcluded != true,
            (targetWindow?.fullscreen ?? false && Defaults[.ignoreFullscreen]) == false
        else {
            return
        }

        // Only recalculate wallpaper colors if Loop was last triggered over 5 seconds ago
        if Defaults[.processWallpaper], lastLoopActivation.distance(to: .now) > 5.0 {
            Task {
                await WallpaperProcessor.fetchLatestWallpaperColors()
            }
        }

        lastLoopActivation = .now
        currentAction = .init(.noAction)
        parentCycleAction = nil
        initialMousePosition = NSEvent.mouseLocation
        screenToResizeOn = Defaults[.useScreenWithCursor] ? NSScreen.screenWithMouse : NSScreen.main
        keybindMonitor.start()

        leftClickMonitor = CGEventMonitor(
            eventMask: [.leftMouseDown],
            callback: { cgEvent in
                guard self.isLoopActive else {
                    return Unmanaged.passUnretained(cgEvent)
                }

                if cgEvent.type == .leftMouseDown,
                   let parentCycleAction = self.parentCycleAction {
                    self.changeAction(parentCycleAction, disableHapticFeedback: true)
                }

                return nil
            }
        )

        if !Defaults[.disableCursorInteraction] {
            mouseMovedEventMonitor?.start()
        }

        if !Defaults[.hideUntilDirectionIsChosen] {
            openWindows()
        }

        if let window = targetWindow {
            LoopManager.lastTargetFrame = window.frame
        }

        isLoopActive = true
    }

    func closeLoop(forceClose: Bool = false) {
        guard isLoopActive == true else { return }

        triggerDelayTimer = nil
        closeWindows()

        keybindMonitor.stop()
        mouseMovedEventMonitor?.stop()
        leftClickMonitor?.stop()

        currentlyPressedModifiers = []

        if targetWindow != nil,
           screenToResizeOn != nil,
           forceClose == false,
           currentAction.direction != .noAction,
           isLoopActive {
            if let screenToResizeOn,
               Defaults[.previewVisibility] {
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
        }

        isLoopActive = false
        LoopManager.sidesToAdjust = nil
        LoopManager.lastTargetFrame = .zero
    }

    func openWindows() {
        if Defaults[.previewVisibility], targetWindow != nil {
            previewController.open(
                screen: screenToResizeOn!,
                window: targetWindow
            )
        }

        if Defaults[.radialMenuVisibility] {
            radialMenuController.open(
                position: initialMousePosition,
                frontmostWindow: targetWindow
            )
        }
    }

    func closeWindows() {
        radialMenuController.close()
        previewController.close()
    }
}

// MARK: - Triggering

private extension LoopManager {
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

    func handleTriggerDelay() {
        if triggerDelayTimer == nil {
            triggerDelayTimer = Timer.scheduledTimer(
                withTimeInterval: Double(Defaults[.triggerDelay]),
                repeats: false
            ) { _ in
                self.openLoop()
            }
        }
    }

    func handleDoubleClickToTrigger(_ useTriggerDelay: Bool) {
        if abs(lastTriggerKeyClick.timeIntervalSinceNow) < NSEvent.doubleClickInterval {
            if useTriggerDelay {
                handleTriggerDelay()
            } else {
                openLoop()
            }
        }
    }

    func handleLoopKeypress(_ event: NSEvent) -> NSEvent? {
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
                return nil
            }

            let useTriggerDelay = Defaults[.triggerDelay] > 0.1
            let useDoubleClickTrigger = Defaults[.doubleClickToTrigger]

            if useDoubleClickTrigger {
                guard currentlyPressedModifiers.sorted() == Defaults[.triggerKey].sorted() else { return nil }
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

        return nil
    }

    func processModifiers(_ event: NSEvent) {
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
}

// MARK: - Changing Actions

private extension LoopManager {
    /// Changes the action to the provided one, or the next cycle action if available.
    /// - Parameters:
    ///   - newAction: The action to change to. If a cycle is provided, Loop will use the current action as context to choose an appropriate next action.
    ///   - triggeredFromScreenChange: If this action was triggered from a screen change, this will prevent cycle keybinds from infinitely changing screens.
    ///   - disableHapticFeedback: This will prevent haptic feedback.
    ///   - canAdvanceCycle: This will prevent the cycle from advancing if set to false. This is currently used when changing actions via the radial menu.
    func changeAction(
        _ newAction: WindowAction,
        triggeredFromScreenChange: Bool = false,
        disableHapticFeedback: Bool = false,
        canAdvanceCycle: Bool = true
    ) {
        // This will allow us to compare different window actions without needing to consider different keybinds/custom names/ids.
        // This is useful when the radial menu and keybinds have the same set of cycle actions, so we don't need to worry about not having a keybind.
        var newAction = newAction.stripNonResizingProperties()

        guard
            currentAction != newAction || newAction.willManipulateExistingWindowFrame,
            isLoopActive,
            let currentScreen = screenToResizeOn
        else {
            return
        }

        if newAction.direction == .cycle {
            parentCycleAction = newAction

            // The ability to advance a cycle is only available when the action is triggered via a keybind or a left click on the mouse.
            // This will be set to false when the mouse is *moved* to prevent erratic behavior.
            if canAdvanceCycle {
                newAction = getNextCycleAction(newAction)
            } else {
                if let cycle = newAction.cycle, !cycle.contains(currentAction) {
                    newAction = cycle.first ?? .init(.noAction)
                } else {
                    newAction = currentAction
                }

                if newAction == currentAction {
                    return
                }
            }

            // Prevents an endless loop of cycling screens. example: when a cycle only consists of:
            // 1. next screen
            // 2. previous screen
            if triggeredFromScreenChange, newAction.direction.willChangeScreen {
                performHapticFeedback()
                return
            }
        } else {
            // By removing the parent cycle action, a left click will not advance the user's previously set cycle.
            parentCycleAction = nil
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

            if newAction.direction == .cycle {
                currentAction = newAction
                changeAction(newAction, triggeredFromScreenChange: true)
            } else {
                if let screenToResizeOn,
                   let window = targetWindow,
                   !Defaults[.previewVisibility] {
                    if !disableHapticFeedback {
                        performHapticFeedback()
                    }

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

        if !disableHapticFeedback {
            performHapticFeedback()
        }

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

    func getNextCycleAction(_ action: WindowAction) -> WindowAction {
        guard let currentCycle = action.cycle else {
            return action
        }

        var nextIndex = 0

        // If the current action is noAction, we can preserve the index from the last action.
        // This would initially be done by reading the window's records, then would continue by finding the next index from the currentAction.
        if currentAction.direction == .noAction,
           !currentCycle.contains(currentAction),
           let window = targetWindow,
           let latestRecord = WindowRecords.getCurrentAction(for: window) {
            nextIndex = (currentCycle.firstIndex(of: latestRecord) ?? -1) + 1
        } else {
            nextIndex = (currentCycle.firstIndex(of: currentAction) ?? -1) + 1
        }

        if nextIndex >= currentCycle.count {
            nextIndex = 0
        }

        return currentCycle[nextIndex]
    }

    func performHapticFeedback() {
        if Defaults[.hapticFeedback] {
            NSHapticFeedbackManager.defaultPerformer.perform(
                NSHapticFeedbackManager.FeedbackPattern.alignment,
                performanceTime: NSHapticFeedbackManager.PerformanceTime.now
            )
        }
    }
}

// MARK: - Radial Menu

private extension LoopManager {
    func mouseMoved(_: NSEvent) -> NSEvent? {
        guard isLoopActive else { return nil }
        keybindMonitor.canPassthroughSpecialEvents = false

        let noActionDistance: CGFloat = 10

        let currentMouseLocation = NSEvent.mouseLocation
        let mouseAngle = Angle(radians: initialMousePosition.angle(to: currentMouseLocation))
        let mouseDistance = initialMousePosition.distanceSquared(to: currentMouseLocation)

        // Return if the mouse didn't move
        if mouseAngle == angleToMouse, mouseDistance == distanceToMouse {
            return nil
        }

        // Get angle & distance to mouse
        angleToMouse = mouseAngle
        distanceToMouse = mouseDistance

        var resizeDirection: WindowAction = .init(.noAction)

        // If mouse over 50 points away, select half or quarter positions
        if distanceToMouse > pow(50 - Defaults[.radialMenuThickness], 2) {
            switch Int((angleToMouse.normalized().degrees + 22.5) / 45) {
            case 0, 8: resizeDirection = Defaults[.radialMenuRight]
            case 1: resizeDirection = Defaults[.radialMenuBottomRight]
            case 2: resizeDirection = Defaults[.radialMenuBottom]
            case 3: resizeDirection = Defaults[.radialMenuBottomLeft]
            case 4: resizeDirection = Defaults[.radialMenuLeft]
            case 5: resizeDirection = Defaults[.radialMenuTopLeft]
            case 6: resizeDirection = Defaults[.radialMenuTop]
            case 7: resizeDirection = Defaults[.radialMenuTopRight]
            default: break
            }
        } else if distanceToMouse > pow(noActionDistance, 2) {
            resizeDirection = Defaults[.radialMenuCenter]
        }

        changeAction(resizeDirection, canAdvanceCycle: false)

        return nil
    }
}
