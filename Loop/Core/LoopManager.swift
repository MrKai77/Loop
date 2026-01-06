//
//  LoopManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-15.
//

import Defaults
import Scribe
import SwiftUI

// MARK: - LoopManager

final class LoopManager: ObservableObject {
    static let shared = LoopManager()
    private init() {}

    // Size Adjustment
    static var sidesToAdjust: Edge.Set?
    static var lastTargetFrame: CGRect = .zero

    private let windowActionCache = WindowActionCache()
    private let radialMenuController = RadialMenuController()
    private let previewController = PreviewController()

    private lazy var triggerKeyTimeoutTimer = TriggerKeyTimeoutTimer(
        closeCallback: { [weak self] in self?.closeLoop(forceClose: $0) }
    )

    private(set) lazy var keybindTrigger = KeybindTrigger(
        windowActionCache: windowActionCache,
        openCallback: { [weak self] in self?.openLoop(startingAction: $0) },
        closeCallback: { [weak self] in self?.closeLoop(forceClose: $0) },
        checkIfLoopOpen: { [weak self] in self?.isLoopActive ?? false }
    )

    private(set) lazy var middleClickTrigger = MiddleClickTrigger(
        openCallback: { [weak self] in self?.openLoop(startingAction: $0) },
        closeCallback: { [weak self] in self?.closeLoop(forceClose: $0) },
        checkIfLoopOpen: { [weak self] in self?.isLoopActive ?? false }
    )

    private(set) lazy var mouseInteractionObserver = MouseInteractionObserver(
        windowActionCache: windowActionCache,
        changeAction: { [weak self] newAction in
            /// If the mouse moved, that means that the keybind trigger should no longer passthrough special events such as the emoji key.
            self?.keybindTrigger.canPassthroughSpecialEvents = false
            self?.changeAction(newAction, canAdvanceCycle: false)
        },
        selectNextCycleItem: { [weak self] in
            if let parentCycleAction = self?.parentCycleAction {
                self?.changeAction(parentCycleAction, disableHapticFeedback: true)
            }
        },
        checkIfLoopOpen: { [weak self] in self?.isLoopActive ?? false }
    )

    private var accessibilityCheckerTask: Task<(), Never>?

    private(set) var isLoopActive: Bool = false
    private var targetWindow: Window?
    private var screenToResizeOn: NSScreen?
    var isShiftKeyPressed: Bool = false

    @Published var currentAction: WindowAction = .init(.noSelection)
    private var parentCycleAction: WindowAction?
    private(set) var initialMousePosition: CGPoint = .zero

    func start() {
        accessibilityCheckerTask = Task(priority: .background) { [weak self] in
            for await status in AccessibilityManager.shared.stream(initial: true) {
                guard let self, !Task.isCancelled else {
                    return
                }

                if status {
                    await keybindTrigger.start()
                    await middleClickTrigger.start()
                } else {
                    await keybindTrigger.stop()
                    await middleClickTrigger.stop()
                }
            }
        }
    }
}

// MARK: - Opening/Closing Loop

extension LoopManager {
    private func openLoop(startingAction: WindowAction) {
        guard AccessibilityManager.shared.isGranted else {
            return
        }

        guard !isLoopActive else {
            /// If using Karabiner-Elements, TriggerKeybindObserver may call openLoop twice, as key events arrive in quick succession.
            /// This happens because Karabiner-Elements sends modifier keys and other keys as separate, rapid events.
            /// As a result, Loop might be opened before the full keybind is pressed.
            /// In these cases, we can simply update the action instead of reopening the Loop.
            if startingAction.direction != .noSelection {
                changeAction(startingAction, disableHapticFeedback: true)
            }

            return
        }

        let window = WindowUtility.userDefinedTargetWindow()

        guard
            window?.isAppExcluded != true,
            (window?.fullscreen ?? false && Defaults[.ignoreFullscreen]) == false
        else {
            return
        }

        Log.info("Opening Loop with starting action: \(startingAction.description) and target window: \(window?.description ?? "(none)")", category: .loopManager)

        // Refresh accent colors in case user has enabled the wallpaper processor
        Task {
            await AccentColorController.shared.refresh()
        }

        currentAction = .init(.noSelection)
        targetWindow = window
        parentCycleAction = nil
        initialMousePosition = NSEvent.mouseLocation
        screenToResizeOn = nil // Screen to resize on will be determined by the first action.
        isShiftKeyPressed = false

        if !Defaults[.disableCursorInteraction] {
            Task { @MainActor in
                mouseInteractionObserver.start(initialMousePosition: initialMousePosition)
            }
        }

        if !Defaults[.hideUntilDirectionIsChosen] {
            openWindows(startingAction: startingAction, window: window)
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
        changeAction(startingAction, disableHapticFeedback: true)

        triggerKeyTimeoutTimer.start()
    }

    private func closeLoop(forceClose: Bool) {
        guard isLoopActive == true else { return }
        Log.info("Closing Loop (force closed: \(forceClose))", category: .loopManager)

        closeWindows()
        isLoopActive = false

        triggerKeyTimeoutTimer.cancel()

        Task { @MainActor in
            mouseInteractionObserver.stop()
        }

        // Handle normal actions with a target window
        if let targetWindow,
           let screenToResizeOn,
           forceClose == false,
           !currentAction.direction.willFocusWindow {
            // If the preview was disabled, the window will already be in the specified action's frame.
            // So only resize the window if the preview is enabled.
            if Defaults[.previewVisibility] {
                WindowEngine.resize(
                    targetWindow,
                    to: currentAction,
                    on: screenToResizeOn
                )
            }

            // Icon stuff
            Defaults[.timesLooped] += 1
            IconManager.checkIfUnlockedNewIcon()
        }

        LoopManager.sidesToAdjust = nil
        LoopManager.lastTargetFrame = .zero
    }

    private func openWindows(startingAction: WindowAction, window: Window?) {
        if Defaults[.previewVisibility], let screenToResizeOn {
            previewController.open(
                screen: screenToResizeOn,
                window: window,
                startingAction: startingAction
            )
        }

        if Defaults[.radialMenuVisibility] {
            radialMenuController.open(
                position: initialMousePosition,
                window: window,
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
            isLoopActive,
            currentAction.id != newAction.id || newAction.canRepeat,
            let currentScreen = screenToResizeOn ?? resolveAndStoreTargetScreen(
                action: newAction,
                window: targetWindow
            )
        else {
            return
        }

        var newAction = newAction

        triggerKeyTimeoutTimer.cancel()
        triggerKeyTimeoutTimer.start()

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
               let leftScreen = ScreenUtility.directionalScreen(from: currentScreen, direction: .left) {
                newScreen = leftScreen
            }

            if newAction.direction == .rightScreen,
               let rightScreen = ScreenUtility.directionalScreen(from: currentScreen, direction: .right) {
                newScreen = rightScreen
            }

            if newAction.direction == .topScreen,
               let topScreen = ScreenUtility.directionalScreen(from: currentScreen, direction: .top) {
                newScreen = topScreen
            }

            if newAction.direction == .bottomScreen,
               let bottomScreen = ScreenUtility.directionalScreen(from: currentScreen, direction: .bottom) {
                newScreen = bottomScreen
            }

            if currentAction.direction == .noSelection || currentAction.willManipulateExistingWindowFrame {
                if let targetWindow {
                    let screenSwitchingCustomActionName = "autogenerated_screen_switching_action"

                    if let lastAction = WindowRecords.getCurrentAction(for: targetWindow),
                       lastAction.getName() != screenSwitchingCustomActionName,
                       !lastAction.forceProportionalFrameOnScreenChange {
                        currentAction = lastAction
                    } else {
                        let currentFrame = targetWindow.frame

                        let adjustedBounds = PaddingSettings
                            .configuredPadding(for: currentScreen)
                            .apply(onScreenFrame: currentScreen.safeScreenFrame)

                        let proportionalSize = CGRect(
                            x: (currentFrame.minX - adjustedBounds.minX) / adjustedBounds.width,
                            y: (currentFrame.minY - adjustedBounds.minY) / adjustedBounds.height,
                            width: currentFrame.width / adjustedBounds.width,
                            height: currentFrame.height / adjustedBounds.height
                        )

                        currentAction = .init(
                            .custom,
                            keybind: [],
                            name: screenSwitchingCustomActionName,
                            unit: .percentage,
                            width: proportionalSize.width * 100,
                            height: proportionalSize.height * 100,
                            xPoint: proportionalSize.minX * 100,
                            yPoint: proportionalSize.minY * 100,
                            positionMode: .coordinates,
                            sizeMode: .custom
                        )
                    }
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
                if let window = targetWindow,
                   !Defaults[.previewVisibility] {
                    if !disableHapticFeedback {
                        performHapticFeedback()
                    }

                    WindowEngine.resize(
                        window,
                        to: currentAction,
                        on: newScreen
                    )
                }
            }

            Log.info("Screen changed: \(newScreen.localizedName)", category: .loopManager)

            return
        }

        if !disableHapticFeedback {
            performHapticFeedback()
        }

        if newAction != currentAction || newAction.canRepeat {
            currentAction = newAction

            if Defaults[.hideUntilDirectionIsChosen] {
                openWindows(startingAction: newAction, window: targetWindow)
            }

            Task { @MainActor in
                previewController.setAction(to: newAction)
                radialMenuController.setAction(to: newAction)

                if !Defaults[.previewVisibility], let screenToResizeOn, let targetWindow {
                    WindowEngine.resize(
                        targetWindow,
                        to: newAction,
                        on: screenToResizeOn
                    )
                }

                // If the action is to focus a window in a specific direction, find and activate that window
                // This can work even without a current window (navigates from screen center)
                if newAction.direction.willFocusWindow {
                    var newTargetWindow: Window?

                    if newAction.direction == .focusNextInStack,
                       let newWindow = WindowUtility.focusNextWindowInStack(from: targetWindow) {
                        newTargetWindow = newWindow
                    }

                    if let focusDirection = newAction.direction.focusDirection,
                       let newWindow = WindowUtility.focusWindow(from: targetWindow, direction: focusDirection) {
                        newTargetWindow = newWindow
                    }

                    if let newTargetWindow {
                        targetWindow = newTargetWindow
                        previewController.setWindow(to: newTargetWindow)
                        radialMenuController.setWindow(to: newTargetWindow)

                        // If the previous window was nil, then the preview may have not opened.
                        // So open them here just in case.
                        openWindows(startingAction: newAction, window: newTargetWindow)
                    }
                }
            }

            Log.info("Window action changed: \(newAction.description)", category: .loopManager)
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
           currentAction.direction == .noSelection || !currentCycle.contains(currentAction) {
            return currentCycle[0]
        }

        // If the current action is noSelection, we can preserve the index from the last action.
        // This would initially be done by reading the window's records, then would continue by finding the next index from the currentAction.
        if currentAction.direction == .noSelection,
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

    /// Resolves the target screen for `screenToResizeOn`.
    ///
    /// By default, this uses the user's `useScreenWithCursor` setting.
    /// For actions that move windows between screens, the screen containing the window is preferred to ensure deterministic behavior.
    /// - Parameters:
    ///   - action: The window action being performed.
    ///   - window: The window to be resized, if any.
    /// - Returns: The screen the window should be on after the action.
    private func resolveAndStoreTargetScreen(action: WindowAction, window: Window?) -> NSScreen? {
        var targetScreen = Defaults[.useScreenWithCursor] ? NSScreen.screenWithMouse : NSScreen.main

        if action.direction.willChangeScreen,
           let window,
           let screen = ScreenUtility.screenContaining(window) {
            targetScreen = screen
        }

        screenToResizeOn = targetScreen

        // If a screen was previously not selected, then the preview needs to be opened.
        openWindows(startingAction: action, window: targetWindow)

        return targetScreen
    }
}
