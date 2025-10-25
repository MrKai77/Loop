//
//  LoopManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-15.
//

import Defaults
import OSLog
import SwiftUI

// MARK: - LoopManager

final class LoopManager: ObservableObject {
    static let shared = LoopManager()
    private init() {}

    private let logger = Logger(category: "LoopManager")

    // Size Adjustment
    static var sidesToAdjust: Edge.Set?
    static var lastTargetFrame: CGRect = .zero

    private let radialMenuController = RadialMenuController()
    private let previewController = PreviewController()

    private(set) lazy var keybindObserver = KeybindObserver(
        openCallback: { [weak self] in self?.openLoop(startingAction: $0) },
        closeCallback: { [weak self] in self?.closeLoop(forceClose: $0) },
        checkIfLoopOpen: { [weak self] in self?.isLoopActive ?? false }
    )

    private(set) lazy var middleClickObserver = MiddleClickObserver(
        openCallback: { [weak self] in self?.openLoop(startingAction: $0) },
        closeCallback: { [weak self] in self?.closeLoop(forceClose: false) }
    )

    private(set) lazy var mouseMovedEventMonitor = PassiveEventMonitor(
        events: [.mouseMoved],
        callback: mouseMoved
    )

    private(set) lazy var leftClickMonitor = PassiveEventMonitor(
        events: [.leftMouseDown],
        callback: leftMouseDown
    )

    private var accessibilityCheckerTask: Task<(), Never>?

    private(set) var isLoopActive: Bool = false
    private var targetWindow: Window?
    private var screenToResizeOn: NSScreen?
    var isShiftKeyPressed: Bool = false

    @Published var currentAction: WindowAction = .init(.noAction)
    private var parentCycleAction: WindowAction?
    private(set) var initialMousePosition: CGPoint = .init()
    private var angleToMouse: Angle = .init(degrees: 0)
    private var distanceToMouse: CGFloat = 0

    func start() {
        accessibilityCheckerTask = Task(priority: .background) { [weak self] in
            for await status in AccessibilityManager.shared.stream(initial: true) {
                guard let self, !Task.isCancelled else {
                    return
                }

                if status {
                    await keybindObserver.start()
                    await middleClickObserver.start()
                } else {
                    await keybindObserver.stop()
                    await middleClickObserver.stop()
                }
            }
        }
    }
}

// MARK: - Opening/Closing Loop

extension LoopManager {
    private func openLoop(startingAction: WindowAction?) {
        guard AccessibilityManager.shared.isGranted else {
            return
        }

        guard !isLoopActive else {
            /// If using Karabiner-Elements, TriggerKeybindObserver may call openLoop twice.
            /// This happens because Karabiner-Elements sends modifier keys and other keys as separate, rapid events.
            /// As a result, Loop might be opened before the full keybind is pressed.
            /// In these cases, we can simply update the action instead of reopening the Loop.
            /// Enabling keybindObserver was considered as a workaround, but it doesn't start quickly enough.
            /// Although Karabiner-Elements sends key events separately, they arrive in quick succession.
            if let startingAction {
                changeAction(startingAction, disableHapticFeedback: true)
            }
            return
        }

        targetWindow = WindowUtility.userDefinedTargetWindow()
        guard
            targetWindow?.isAppExcluded != true,
            (targetWindow?.fullscreen ?? false && Defaults[.ignoreFullscreen]) == false
        else {
            return
        }

        // Record the first frame in advance if the preview window is disabled
        if let targetWindow,
           !WindowRecords.hasBeenRecorded(targetWindow),
           !Defaults[.previewVisibility] {
            WindowRecords.recordFirst(for: targetWindow)
        }

        // Refresh accent colors in case user has enabled the wallpaper processor
        Task {
            await AccentColorController.shared.refresh()
        }

        currentAction = .init(.noAction)
        parentCycleAction = nil
        initialMousePosition = NSEvent.mouseLocation
        screenToResizeOn = Defaults[.useScreenWithCursor] ? NSScreen.screenWithMouse : NSScreen.main
        isShiftKeyPressed = false

        if !Defaults[.disableCursorInteraction] {
            mouseMovedEventMonitor.start()
            leftClickMonitor.start()
        }

        if !Defaults[.hideUntilDirectionIsChosen] {
            openWindows(startingAction: startingAction)
        }

        if let window = targetWindow {
            // In case of a stashed window, use the revealed frame instead to prevent issue with frame calculation later.
            if let frame = StashManager.shared.getRevealedFrameForStashedWindow(id: window.cgWindowID) {
                LoopManager.lastTargetFrame = frame
            } else {
                LoopManager.lastTargetFrame = window.frame
            }
        }

        isLoopActive = true

        if let startingAction {
            changeAction(startingAction, disableHapticFeedback: true)
        }
    }

    private func closeLoop(forceClose: Bool) {
        guard isLoopActive == true else { return }

        closeWindows()

        mouseMovedEventMonitor.stop()
        leftClickMonitor.stop()

        if let targetWindow,
           let screenToResizeOn,
           forceClose == false,
           currentAction.direction != .noAction,
           isLoopActive {
            if Defaults[.previewVisibility] {
                WindowEngine.resize(
                    targetWindow,
                    to: currentAction,
                    on: screenToResizeOn
                )
            } else {
                WindowRecords.record(
                    targetWindow,
                    currentAction
                )
            }

            // Icon stuff
            Defaults[.timesLooped] += 1
            IconManager.checkIfUnlockedNewIcon()
        }

        isLoopActive = false
        LoopManager.sidesToAdjust = nil
        LoopManager.lastTargetFrame = .zero
    }

    private func openWindows(startingAction: WindowAction?) {
        if Defaults[.previewVisibility], targetWindow != nil {
            previewController.open(
                screen: screenToResizeOn!,
                window: targetWindow,
                startingAction: startingAction
            )
        }

        if Defaults[.radialMenuVisibility] {
            radialMenuController.open(
                position: initialMousePosition,
                window: targetWindow,
                startingAction: startingAction
            )
        }
    }

    private func closeWindows() {
        radialMenuController.close()
        previewController.close()
    }
}

// MARK: - Changing Actions

extension LoopManager {
    /// Changes the action to the provided one, or the next cycle action if available.
    /// - Parameters:
    ///   - newAction: The action to change to. If a cycle is provided, Loop will use the current action as context to choose an appropriate next action.
    ///   - triggeredFromScreenChange: If this action was triggered from a screen change, this will prevent cycle keybinds from infinitely changing screens.
    ///   - disableHapticFeedback: This will prevent haptic feedback.
    ///   - canAdvanceCycle: This will prevent the cycle from advancing if set to false. This is currently used when changing actions via the radial menu.
    private func changeAction(
        _ newAction: WindowAction,
        triggeredFromScreenChange: Bool = false,
        disableHapticFeedback: Bool = false,
        canAdvanceCycle: Bool = true
    ) {
        guard
            !currentAction.isSameManipulation(as: newAction) || newAction.willManipulateExistingWindowFrame,
            isLoopActive,
            let currentScreen = screenToResizeOn
        else {
            return
        }

        var newAction = newAction

        if StashManager.shared.handleIfStashed(newAction, screen: currentScreen) {
            return
        }

        if newAction.direction == .cycle {
            parentCycleAction = newAction

            // The ability to advance a cycle is only available when the action is triggered via a keybind or a left click on the mouse.
            // This should be set to false when the mouse is moved to prevent rapid cycling.
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
            var newScreen: NSScreen = currentScreen

            if newAction.direction == .nextScreen,
               let nextScreen = ScreenUtility.nextScreen(from: currentScreen) {
                newScreen = nextScreen
            }

            if newAction.direction == .previousScreen,
               let previousScreen = ScreenUtility.previousScreen(from: currentScreen) {
                newScreen = previousScreen
            }

            if newAction.direction == .leftScreen,
               let leftScreen = ScreenUtility.directionalScreen(from: currentScreen, edge: .leading) {
                newScreen = leftScreen
            }

            if newAction.direction == .rightScreen,
               let rightScreen = ScreenUtility.directionalScreen(from: currentScreen, edge: .trailing) {
                newScreen = rightScreen
            }

            if newAction.direction == .topScreen,
               let topScreen = ScreenUtility.directionalScreen(from: currentScreen, edge: .top) {
                newScreen = topScreen
            }

            if newAction.direction == .bottomScreen,
               let bottomScreen = ScreenUtility.directionalScreen(from: currentScreen, edge: .bottom) {
                newScreen = bottomScreen
            }

            if currentAction.direction == .noAction {
                if let targetWindow, let lastAction = WindowRecords.getCurrentAction(for: targetWindow) {
                    currentAction = lastAction
                } else {
                    currentAction = .init(.center)
                }
            }

            screenToResizeOn = newScreen
            previewController.setScreen(to: newScreen)

            // This is only needed because if preview window is moved
            // onto a new screen, it needs to receive a window action
            previewController.setAction(to: currentAction)
            radialMenuController.setAction(to: currentAction)

            if let parentCycleAction {
                currentAction = newAction
                changeAction(parentCycleAction, triggeredFromScreenChange: true)
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
                        on: screenToResizeOn,
                        shouldRecord: false
                    )
                }
            }

            logger.info("Screen changed: \(newScreen.localizedName)")

            return
        }

        if !disableHapticFeedback {
            performHapticFeedback()
        }

        if newAction != currentAction || newAction.willManipulateExistingWindowFrame {
            currentAction = newAction

            if Defaults[.hideUntilDirectionIsChosen] {
                openWindows(startingAction: newAction)
            }

            DispatchQueue.main.async {
                self.previewController.setAction(to: newAction)
                self.radialMenuController.setAction(to: newAction)

                if !Defaults[.previewVisibility], let screenToResizeOn = self.screenToResizeOn, let window = self.targetWindow {
                    WindowEngine.resize(
                        window,
                        to: newAction,
                        on: screenToResizeOn,
                        shouldRecord: false
                    )
                }
            }

            logger.info("Window action changed: \(newAction.debugDescription)")
        }
    }

    private func getNextCycleAction(_ action: WindowAction) -> WindowAction {
        guard let currentCycle = action.cycle else {
            return action
        }

        // Allow cycling backwards only if:
        // - Shift is not part of the action's keybind (eligibleForReverseCycle)
        // - Shift is not part of the trigger key
        // - The user has enabled the setting
        let allowReverseCycle = action.eligibleForReverseCycle
            && Defaults[.triggerKey].contains(.kVK_Shift) == false
            && Defaults[.cycleBackwardsOnShiftPressed]

        let shouldCycleBackwards = allowReverseCycle && isShiftKeyPressed
        var currentIndex: Int? = nil

        if Defaults[.cycleModeRestartEnabled],
           currentAction.direction == .noAction ||
           !currentCycle.contains(currentAction) {
            return currentCycle[0]
        }

        // If the current action is noAction, we can preserve the index from the last action.
        // This would initially be done by reading the window's records, then would continue by finding the next index from the currentAction.
        if currentAction.direction == .noAction,
           !currentCycle.contains(currentAction),
           let window = targetWindow,
           let latestRecord = WindowRecords.getCurrentAction(for: window) {
            currentIndex = currentCycle.firstIndex(of: latestRecord)
        } else {
            currentIndex = currentCycle.firstIndex(of: currentAction)
        }

        guard var nextIndex = currentIndex else {
            return currentCycle[0]
        }

        nextIndex += shouldCycleBackwards ? -1 : 1

        // Wrap around the cycle index if we've reached the end or gone before the start.
        if nextIndex >= currentCycle.count {
            nextIndex = 0
        }

        if nextIndex < 0 {
            nextIndex = currentCycle.count - 1
        }

        return currentCycle[nextIndex]
    }

    private func performHapticFeedback() {
        if Defaults[.hapticFeedback] {
            NSHapticFeedbackManager.defaultPerformer.perform(
                NSHapticFeedbackManager.FeedbackPattern.alignment,
                performanceTime: NSHapticFeedbackManager.PerformanceTime.now
            )
        }
    }
}

// MARK: - Radial Menu

extension LoopManager {
    private func mouseMoved(cgEvent _: CGEvent) {
        Task { @MainActor in
            guard isLoopActive else { return }
            keybindObserver.canPassthroughSpecialEvents = false

            let noActionDistance: CGFloat = 10

            let currentMouseLocation = NSEvent.mouseLocation
            let mouseAngle = Angle(radians: initialMousePosition.angle(to: currentMouseLocation))
            let mouseDistance = initialMousePosition.distance(to: currentMouseLocation)

            // Return if the mouse didn't move
            if mouseAngle == angleToMouse, mouseDistance == distanceToMouse {
                return
            }

            // Get angle & distance to mouse
            angleToMouse = mouseAngle
            distanceToMouse = mouseDistance

            var resizeDirection: WindowAction = .init(.noAction)

            // If mouse over 50 points away, select half or quarter positions
            if distanceToMouse > 50 - Defaults[.radialMenuThickness] {
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
            } else if distanceToMouse > noActionDistance {
                resizeDirection = Defaults[.radialMenuCenter]
            }

            changeAction(resizeDirection, canAdvanceCycle: false)
        }
    }

    private func leftMouseDown(cgEvent event: CGEvent) {
        /// Ensure that the source originates from the HID state ID.
        /// Otherwise, this event was likely sent from Loop to focus the frontmost click (see `Window.focus` which sends a `SLSEvent` to the window)
        let sourceID = CGEventSourceStateID(rawValue: Int32(event.getIntegerValueField(.eventSourceStateID)))
        guard sourceID == .hidSystemState else {
            return
        }

        Task { @MainActor [weak self] in
            guard let self, isLoopActive, currentAction.direction != .noAction else {
                return
            }

            if let parentCycleAction {
                changeAction(parentCycleAction, disableHapticFeedback: true)
            }
        }
    }
}
