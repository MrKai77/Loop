//
//  MultitouchTrigger.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-30.
//

import Defaults
import Scribe
import Subsurface
import SwiftUI

@Loggable
@MainActor
final class MultitouchTrigger {
    private let windowActionCache: WindowActionCache
    private let openCallback: (WindowAction, Window) async throws -> LoopOpenResult
    private let closeCallback: (Bool) -> ()
    private let changeAction: (WindowAction, Bool) -> ()
    private let checkIfLoopOpen: () -> Bool

    private let gestureMonitor = SubsurfaceMonitor()
    private let gestureBlocker: MultitouchGestureBlocker = .init()
    lazy var recognizerRegistry = MultitouchRecognizerRegistry(
        gestureMonitor: gestureMonitor
    ) { [weak self] event, fingerCount in
        guard let self else { return }
        await handleGestureEvent(event, fingerCount: fingerCount)
    }

    let targetResolver = MultitouchTargetResolver()

    private var gesturesObservationTask: Task<(), Never>?
    private var radialMenuActionsObservationTask: Task<(), Never>?
    private var systemGestureReconciliationTask: Task<(), Never>?
    private var isStarted = false

    let swipeCycleStepSize: CGFloat = 0.15
    let magnifyStepSize: CGFloat = 0.2
    let cardinalBiasedRadialMenuActionCount = 8

    var radialMenuActions = RadialMenuAction.userConfiguredActions

    private static let failedToResolveKeybindAction: WindowAction = .init(.noAction)

    init(
        windowActionCache: WindowActionCache,
        openCallback: @escaping (WindowAction, Window) async throws -> LoopOpenResult,
        closeCallback: @escaping (Bool) -> (),
        changeAction: @escaping (WindowAction, Bool) -> (),
        checkIfLoopOpen: @escaping () -> Bool
    ) {
        self.windowActionCache = windowActionCache
        self.openCallback = openCallback
        self.closeCallback = closeCallback
        self.changeAction = changeAction
        self.checkIfLoopOpen = checkIfLoopOpen

        startSystemGestureReconciliation()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        startSystemGestureReconciliation()
        reconcileSystemGestures()
        gestureMonitor.start()
        rebuildRecognizers()
        radialMenuActions = RadialMenuAction.userConfiguredActions

        gesturesObservationTask = Task { [weak self] in
            // Watch keybinds too, so gestures referencing a deleted keybind stay in sync.
            for await _ in Defaults.updates(.gestures, .keybinds, initial: false) {
                guard !Task.isCancelled, let self else { break }
                rebuildRecognizers()
            }
        }

        radialMenuActionsObservationTask = Task { [weak self] in
            for await _ in Defaults.updates(.enableRadialMenuCustomization, .radialMenuActions, initial: false) {
                guard !Task.isCancelled, let self else { break }
                radialMenuActions = RadialMenuAction.userConfiguredActions
            }
        }
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false

        reconcileSystemGestures()
        gesturesObservationTask?.cancel()
        gesturesObservationTask = nil
        radialMenuActionsObservationTask?.cancel()
        radialMenuActionsObservationTask = nil

        handleStopResults(recognizerRegistry.stopAll())

        gestureMonitor.stop()
        targetResolver.reset()
    }

    func shutdown() {
        stop()
        systemGestureReconciliationTask?.cancel()
        systemGestureReconciliationTask = nil
        SystemGestureManager.restore()
    }

    private func startSystemGestureReconciliation() {
        guard systemGestureReconciliationTask == nil else { return }

        systemGestureReconciliationTask = Task(priority: .background) { [weak self] in
            let updates = Defaults.updates(
                .enableGestures,
                .disableConflictingSystemGestures,
                .gestures
            )

            for await _ in updates {
                guard !Task.isCancelled, let self else { break }
                reconcileSystemGestures()
            }
        }
    }

    private func reconcileSystemGestures() {
        SystemGestureManager.reconcile(
            enableGestures: isStarted && Defaults[.enableGestures],
            disableConflicts: Defaults[.disableConflictingSystemGestures],
            gestures: Defaults[.gestures]
        )
    }

    private func rebuildRecognizers() {
        handleStopResults(recognizerRegistry.rebuild(with: Defaults[.gestures]))
    }

    private func handleStopResults(_ stopResults: [MultitouchRecognizerRegistry.StopResult]) {
        for stopResult in stopResults {
            if stopResult.didOpenLoopWithGesture {
                closeCallback(false)
            }
            gestureBlocker.stop()
        }
    }

    private func handleGestureEvent(_ event: SubsurfaceGestureEvent, fingerCount: Int) async {
        switch event {
        case let .swipe(swipe):
            await handleSwipe(swipe, fingerCount: fingerCount)
        case let .magnify(magnify):
            await handleMagnify(magnify, fingerCount: fingerCount)
        case .determining:
            await handleEarlyRadialMenuGesture(phase: .determining, fingerCount: fingerCount)
        case .unresolvedEnded:
            await handleEarlyRadialMenuGesture(phase: event.phase, fingerCount: fingerCount)
        case let .rotation(rotation):
            await handleEarlyRadialMenuGesture(phase: rotation.phase, fingerCount: fingerCount)
        }
    }

    /// Resolves the target window and starts blocking trackpad events. Loop itself
    /// isn't opened until the gesture crosses the activation threshold in a `.changed` event.
    func handleGestureBegan(fingerCount: Int, gesture: GestureBinding) {
        let allowsRapidRepeat = resolvedWindowAction(from: gesture)?.allowsRapidRepeat == true
        let window = targetResolver.targetWindow(for: gesture, allowsRapidRepeat: allowsRapidRepeat)

        let loopWasAlreadyOpen = checkIfLoopOpen()

        guard let session = recognizerRegistry.session(for: fingerCount) else { return }
        guard session.begin(targetWindow: window, loopWasAlreadyOpen: loopWasAlreadyOpen) else {
            return
        }

        targetResolver.rememberRepeatableWindow(window, allowsRapidRepeat: allowsRapidRepeat)

        gestureBlocker.start()
    }

    private func handleEarlyRadialMenuGesture(
        phase: SubsurfaceGesturePhase,
        fingerCount: Int
    ) async {
        guard !Defaults[.hideOnNoSelection],
              let gesture = recognizerRegistry.entry(for: fingerCount)?.radialMenuGesture else { return }

        switch phase {
        case .determining, .began, .changed:
            if recognizerRegistry.session(for: fingerCount)?.hasGestureBegun != true {
                handleGestureBegan(fingerCount: fingerCount, gesture: gesture)
            }
            _ = await activateGestureIfNeeded(fingerCount: fingerCount)

        case .ended, .cancelled:
            resetLoopState(for: fingerCount)

        default:
            break
        }
    }

    /// Opens Loop on the target window resolved at `.began`. Magnify In and magnifyOut gestures
    /// gate on the magnify activation threshold; swipe gestures activate on the first
    /// `.began` event Subsurface emits.
    func activateGestureIfNeeded(
        fingerCount: Int,
        magnifyDisplacement: CGFloat? = nil
    ) async -> Bool {
        guard let session = recognizerRegistry.session(for: fingerCount), !session.isGestureRejected else { return false }

        if let magnifyDisplacement,
           abs(magnifyDisplacement) < magnifyStepSize {
            return false
        }

        if session.hasActivated { return true }

        var openedLoop = false
        if let window = session.pendingTargetWindow {
            do {
                let result = try await openCallback(.init(.noSelection), window)
                openedLoop = result == .opened
            } catch {
                if recognizerRegistry.contains(session: session, for: fingerCount) {
                    session.reject()
                }
                gestureBlocker.stop()
                return false
            }
        }

        guard recognizerRegistry.contains(session: session, for: fingerCount) else { return false }
        session.markActivated(openedLoop: openedLoop)
        return true
    }

    func resetLoopState(for fingerCount: Int, forceClose: Bool = false) {
        if recognizerRegistry.session(for: fingerCount)?.didOpenLoopWithThisGesture == true {
            closeCallback(forceClose)
        }

        gestureBlocker.stop()
        recognizerRegistry.session(for: fingerCount)?.reset()
        targetResolver.resetGestureState()
    }
}

// MARK: - Actions

extension MultitouchTrigger {
    func isCycleAction(_ gesture: GestureBinding) -> Bool {
        resolvedWindowAction(from: gesture)?.direction == .cycle
    }

    func triggerRadialMenuAction(at index: Int, from actions: ArraySlice<RadialMenuAction>, reverse: Bool = false) {
        guard actions.indices.contains(index) else { return }
        let action = actions[index]

        let resolvedAction: WindowAction = switch action.type {
        case let .custom(windowAction):
            windowAction
        case let .keybindReference(id):
            resolveKeybindReference(id)
        }

        changeAction(resolvedAction, reverse)
    }

    func resolvedWindowAction(from gesture: GestureBinding) -> WindowAction? {
        guard case let .singleAction(actionType) = gesture.action else { return nil }
        switch actionType {
        case let .custom(action): return action
        case let .keybindReference(id): return resolveKeybindReference(id)
        }
    }

    func triggerSingleAction(from gesture: GestureBinding, reverse: Bool = false) {
        guard let resolvedAction = resolvedWindowAction(from: gesture) else { return }
        changeAction(resolvedAction, reverse)
    }

    private func resolveKeybindReference(_ id: UUID) -> WindowAction {
        if let cached = windowActionCache.actionsByIdentifier[id] {
            return cached
        }
        log.warn("Gesture references keybind \(id) that no longer exists")
        return Self.failedToResolveKeybindAction
    }
}
