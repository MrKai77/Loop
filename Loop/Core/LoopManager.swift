//
//  LoopManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-15.
//

import Defaults
import Scribe
import SwiftUI

@Loggable
@MainActor
final class LoopManager {
    static let shared = LoopManager()
    private init() {}

    /// Context for the current resize operation, tracking frame and edge adjustment state.
    /// Initialized when Loop opens with a target window and screen.
    private(set) var resizeContext: ResizeContext = .init()

    private let windowActionCache = WindowActionCache()
    private let indicatorService = WindowActionIndicatorService()
    private let updater = Updater.shared

    private var accessibilityCheckerTask: Task<(), Never>?

    private(set) var isLoopActive: Bool = false

    private lazy var triggerKeyTimeoutTimer = TriggerKeyTimeoutTimer(
        closeCallback: { [weak self] forceClose in
            Task { await self?.closeLoop(forceClose: forceClose) }
        }
    )

    private(set) lazy var keybindTrigger = KeybindTrigger(
        windowActionCache: windowActionCache,
        openCallback: { [weak self] action in
            Task {
                await self?.openLoop(startingAction: action)
            }
        },
        closeCallback: { [weak self] forceClose in
            Task {
                await self?.closeLoop(forceClose: forceClose)
            }
        },
        checkIfLoopOpen: { [weak self] in
            self?.isLoopActive ?? false
        }
    )

    private(set) lazy var middleClickTrigger = MiddleClickTrigger(
        openCallback: { [weak self] action in
            Task {
                await self?.openLoop(startingAction: action)
            }
        },
        closeCallback: { [weak self] forceClose in
            Task {
                await self?.closeLoop(forceClose: forceClose)
            }
        },
        checkIfLoopOpen: { [weak self] in self?.isLoopActive ?? false }
    )

    private(set) lazy var mouseInteractionObserver = MouseInteractionObserver(
        windowActionCache: windowActionCache,
        changeAction: { [weak self] newAction in
            Task {
                // If the mouse moved, that means that the keybind trigger should no longer passthrough special events such as the emoji key.
                self?.keybindTrigger.canPassthroughNextSpecialEvent = false
                await self?.changeAction(newAction, canAdvanceCycle: false)
            }
        },
        selectNextCycleItem: { [weak self] in
            Task {
                if let parent = self?.resizeContext.parentAction {
                    await self?.changeAction(parent, disableHapticFeedback: true)
                }
            }
        },
        canSelectNextCycleitem: { [weak self] in
            self?.resizeContext.parentAction != nil
        },
        checkIfLoopOpen: { [weak self] in self?.isLoopActive ?? false }
    )

    func start() {
        accessibilityCheckerTask = Task(priority: .background) { [weak self] in
            for await status in AccessibilityManager.shared.stream(initial: true) {
                guard let self, !Task.isCancelled else {
                    return
                }

                if status {
                    await keybindTrigger.start()
                    middleClickTrigger.start()
                } else {
                    keybindTrigger.stop()
                    middleClickTrigger.stop()
                }
            }
        }
    }
}

// MARK: - Opening/Closing Loop

extension LoopManager {
    private func openLoop(startingAction: WindowAction) async {
        guard AccessibilityManager.shared.isGranted else {
            return
        }

        guard !isLoopActive else {
            // If using Karabiner-Elements, TriggerKeybindObserver may call openLoop twice, as key events arrive in quick succession.
            // This happens because Karabiner-Elements sends modifier keys and other keys as separate, rapid events.
            // As a result, Loop might be opened before the full keybind is pressed.
            // In these cases, we can simply update the action instead of reopening the Loop.
            if startingAction.direction != .noSelection { // Can switch to .noAction still!
                await changeAction(startingAction, disableHapticFeedback: true)
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

        log.info("Opening Loop with starting action: \(startingAction.description) and target window: \(window?.description ?? "(none)")")

        // Refresh accent colors in case user has enabled the wallpaper processor
        Task {
            await AccentColorController.shared.refresh()
        }

        let initialFrame: CGRect = if let window {
            // In case of a stashed window, use the revealed frame instead to prevent issue with frame calculation later.
            StashManager.shared.getRevealedFrameForStashedWindow(
                id: window.cgWindowID
            ) ?? window.frame
        } else {
            .zero
        }

        resizeContext = ResizeContext(
            window: window,
            initialFrame: initialFrame,
            initialMousePosition: NSEvent.mouseLocation
        )
        await resizeContext.refreshResolvedState()

        if !Defaults[.disableCursorInteraction] {
            mouseInteractionObserver.start(initialMousePosition: resizeContext.initialMousePosition)
        }

        indicatorService.openAndUpdate(context: resizeContext)

        isLoopActive = true
        await changeAction(startingAction, disableHapticFeedback: true)

        triggerKeyTimeoutTimer.start()
    }

    private func closeLoop(forceClose: Bool) async {
        guard isLoopActive == true else { return }
        log.info("Closing Loop (force closed: \(forceClose))")

        indicatorService.closeAll()
        isLoopActive = false

        triggerKeyTimeoutTimer.cancel()
        mouseInteractionObserver.stop()

        // Handle normal actions with a target window
        if !forceClose {
            // If the preview was disabled, the window will already be in the specified action's frame.
            // So only resize the window if the preview is enabled.
            if Defaults[.previewVisibility],
               !resizeContext.action.direction.willFocusWindow {
                Task {
                    _ = try? await WindowActionEngine.shared.apply(context: resizeContext)
                }
            }

            // Icon stuff
            Defaults[.timesLooped] += 1
            IconManager.checkIfUnlockedNewIcon()
        }

        Task {
            if updater.shouldAutoPresentUpdateWindow {
                await updater.showUpdateWindowIfEligible()
            }
        }
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
    ) async {
        guard
            isLoopActive,
            resizeContext.action.id != newAction.id || newAction.canRepeat,
            let currentScreen = resizeContext.screen ?? resolveAndStoreTargetScreen(
                action: newAction,
                window: resizeContext.window
            )
        else {
            return
        }

        var newAction: WindowAction = newAction
        var newParentAction: WindowAction? = nil

        triggerKeyTimeoutTimer.cancel()
        triggerKeyTimeoutTimer.start()

        if StashManager.shared.handleIfStashed(newAction, screen: currentScreen) {
            return
        }

        if newAction.direction == .cycle {
            newParentAction = newAction

            // The ability to advance a cycle is only available when the action is triggered via a keybind or a left click on the mouse.
            // This should be set to false when the mouse is moved to prevent rapid cycling.
            if canAdvanceCycle {
                newAction = await getNextCycleAction(newAction)
            } else {
                if let cycle = newAction.cycle, !cycle.contains(resizeContext.action) {
                    newAction = cycle.first ?? .init(.noAction)
                } else {
                    newAction = resizeContext.action
                }

                if newAction == resizeContext.action {
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
            newParentAction = nil
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

            // If the current action is either `.noAction`/`.noSelection`, or `.smaller`/`.larger` etc,
            // then we will preserve the window's proportional frame relative to the current screen on the new screen.
            if resizeContext.action.direction.isNoOp || resizeContext.action.willManipulateExistingWindowFrame {
                if let targetWindow = resizeContext.window {
                    let screenSwitchingCustomActionName = "autogenerated_screen_switching_action"

                    if let lastAction = await WindowRecords.shared.getCurrentAction(for: targetWindow),
                       lastAction.getName() != screenSwitchingCustomActionName,
                       !lastAction.forceProportionalFrameOnScreenChange {
                        resizeContext.setAction(to: lastAction, parent: nil)
                    } else {
                        let currentFrame = targetWindow.frame

                        let adjustedBounds = PaddingConfiguration
                            .getConfiguredPadding(for: currentScreen)
                            .applyToBounds(currentScreen.cgSafeScreenFrame, screen: currentScreen)

                        let proportionalSize = CGRect(
                            x: (currentFrame.minX - adjustedBounds.minX) / adjustedBounds.width,
                            y: (currentFrame.minY - adjustedBounds.minY) / adjustedBounds.height,
                            width: currentFrame.width / adjustedBounds.width,
                            height: currentFrame.height / adjustedBounds.height
                        )

                        resizeContext.setAction(
                            to: .init(
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
                            ),
                            parent: nil
                        )
                    }
                } else {
                    resizeContext.setAction(to: .init(.center), parent: nil)
                }
            }

            resizeContext.setScreen(to: newScreen)
            indicatorService.openAndUpdate(context: resizeContext)

            if let parent = newParentAction {
                resizeContext.setAction(to: newAction, parent: newParentAction)
                await changeAction(parent, triggeredFromScreenChange: true)
            } else {
                if !Defaults[.previewVisibility] {
                    if !disableHapticFeedback {
                        performHapticFeedback()
                    }

                    Task {
                        _ = try await WindowActionEngine.shared.apply(context: resizeContext)
                    }
                }
            }

            log.info("Screen changed: \(newScreen.localizedName)")

            return
        }

        if !disableHapticFeedback {
            performHapticFeedback()
        }

        if newAction != resizeContext.action || newAction.canRepeat {
            let previousActionWasNoOp = resizeContext.action.direction.isNoOp
            resizeContext.setAction(to: newAction, parent: newParentAction)
            if !Defaults[.previewVisibility], !previousActionWasNoOp {
                await resizeContext.refreshResolvedState()
            }
            indicatorService.openAndUpdate(context: resizeContext)

            Task {
                if !Defaults[.previewVisibility] {
                    _ = try await WindowActionEngine.shared.apply(context: resizeContext)
                }

                // If the action is to focus a window in a specific direction, find and activate that window
                // This can work even without a current window (navigates from screen center)
                if newAction.direction.willFocusWindow {
                    let result = try await WindowActionEngine.shared.apply(context: resizeContext)

                    if let newTargetWindow = result.newTargetWindow {
                        resizeContext.setWindow(to: newTargetWindow)
                    }
                }
            }

            log.info("Window action changed: \(newAction.description)")
        }
    }

    private func getNextCycleAction(_ action: WindowAction) async -> WindowAction {
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

        let shouldCycleBackwards = allowReverseCycle && keybindTrigger.effectiveEventFlags.contains(.maskShift)
        var currentIndex: Int? = nil

        if Defaults[.cycleModeRestartEnabled],
           resizeContext.action.direction == .noSelection || !currentCycle.contains(resizeContext.action) {
            return currentCycle[0]
        }

        // If the current action is noSelection, we can preserve the index from the last action.
        // This would initially be done by reading the window's records, then would continue by finding the next index from the currentAction.
        if resizeContext.action.direction == .noSelection,
           !currentCycle.contains(resizeContext.action),
           let window = resizeContext.window,
           let latestRecord = await WindowRecords.shared.getCurrentAction(for: window) {
            currentIndex = currentCycle.firstIndex(of: latestRecord)
        } else {
            currentIndex = currentCycle.firstIndex(of: resizeContext.action)
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
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
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

        resizeContext.setScreen(to: targetScreen)

        if !resizeContext.action.direction.isNoOp {
            // If a screen was previously not selected, then the preview needs to be opened.
            indicatorService.openAndUpdate(context: resizeContext)
        }

        return targetScreen
    }
}
