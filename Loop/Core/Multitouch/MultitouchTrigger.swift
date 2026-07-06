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
    private lazy var recognizerRegistry = MultitouchRecognizerRegistry(
        gestureMonitor: gestureMonitor
    ) { [weak self] event, fingerCount in
        guard let self else { return }
        await handleGestureEvent(event, fingerCount: fingerCount)
    }

    private let targetResolver = MultitouchTargetResolver()

    private var gesturesObservationTask: Task<(), Never>?
    private var radialMenuActionsObservationTask: Task<(), Never>?
    private var systemGestureReconciliationTask: Task<(), Never>?
    private var isStarted = false

    private let swipeCycleStepSize: CGFloat = 0.15
    private let magnifyActivationThreshold: CGFloat = 0.3
    private let magnifyCycleStepSize: CGFloat = 0.15
    private let cardinalBiasedRadialMenuActionCount = 8

    private var radialMenuActions = RadialMenuAction.userConfiguredActions

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

        prepare()
    }

    func prepare() {
        reconcileSystemGestures()
        startSystemGestureReconciliation()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        prepare()
        gestureMonitor.start()
        rebuildRecognizers()
        radialMenuActions = RadialMenuAction.userConfiguredActions

        gesturesObservationTask = Task { [weak self] in
            // Watch keybinds too, so gestures referencing a deleted keybind stay in sync.
            for await _ in Defaults.updates(.gestures, .keybinds) {
                guard !Task.isCancelled, let self else { break }
                rebuildRecognizers()
            }
        }

        radialMenuActionsObservationTask = Task { [weak self] in
            for await _ in Defaults.updates(.enableRadialMenuCustomization, .radialMenuActions) {
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

    private nonisolated func reconcileSystemGestures() {
        SystemGestureManager.reconcile(
            enableGestures: Defaults[.enableGestures],
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

    private func handleSwipe(_ swipe: SubsurfaceGestureEvent.SwipeEvent, fingerCount: Int) async {
        guard let entry = recognizerRegistry.entry(for: fingerCount) else { return }

        if let radialMenuGesture = entry.radialMenuGesture {
            await handleRadialMenuSwipe(swipe, fingerCount: fingerCount, gesture: radialMenuGesture)
        } else {
            let direction = directionalSwipeKind(angle: swipe.angle)
            let directionalGesture = matchDirectionalSwipeGesture(kind: direction, from: entry.directionalGestures)
            if directionalGesture != nil || entry.session.hasGestureBegun {
                await handleDirectionalSwipe(
                    swipe,
                    fingerCount: fingerCount,
                    direction: direction,
                    matchedGesture: directionalGesture
                )
            }
        }
    }

    private func handleRadialMenuSwipe(
        _ swipe: SubsurfaceGestureEvent.SwipeEvent,
        fingerCount: Int,
        gesture: GestureBinding
    ) async {
        switch swipe.phase {
        case .began, .changed:
            if swipe.phase == .began, recognizerRegistry.session(for: fingerCount)?.hasGestureBegun != true {
                handleGestureBegan(fingerCount: fingerCount, gesture: gesture)
            }
            guard await activateGestureIfNeeded(fingerCount: fingerCount) else { return }
            guard let session = recognizerRegistry.session(for: fingerCount), !session.isGestureRejected else { return }

            let normalizedAngle = normalizedAngle(fromSubsurfaceAngle: swipe.angle)
            let actions = radialMenuActions.dropLast()
            guard actions.count > 1 else { return }

            let newIndex: Int
            if actions.count == cardinalBiasedRadialMenuActionCount {
                newIndex = indexWithCardinalBias(angle: normalizedAngle, actionCount: actions.count)
            } else {
                let actionAngleSpan = (.pi * 2) / CGFloat(actions.count)
                let halfAngleSpan = actionAngleSpan / 2.0
                newIndex = Int((normalizedAngle + halfAngleSpan) / actionAngleSpan) % actions.count
            }

            session.commitSwipe(
                distance: swipe.distance,
                newKey: .radialSlot(newIndex),
                step: swipeCycleStepSize
            ) { reverse in
                triggerRadialMenuAction(at: newIndex, from: actions, reverse: reverse)
            }

        case .ended, .cancelled:
            resetLoopState(for: fingerCount)

        default:
            break
        }
    }

    private func handleDirectionalSwipe(
        _ swipe: SubsurfaceGestureEvent.SwipeEvent,
        fingerCount: Int,
        direction: GestureBinding.Kind,
        matchedGesture: GestureBinding?
    ) async {
        guard let entry = recognizerRegistry.entry(for: fingerCount) else { return }

        switch swipe.phase {
        case .began, .changed:
            guard let session = recognizerRegistry.session(for: fingerCount), !session.isGestureRejected else { return }

            if !session.hasGestureBegun {
                guard let matchedGesture else { return }
                handleGestureBegan(fingerCount: fingerCount, gesture: matchedGesture)
                recognizerRegistry.session(for: fingerCount)?.setResolvedGesture(matchedGesture)
            }

            guard await activateGestureIfNeeded(fingerCount: fingerCount) else { return }
            guard let session = recognizerRegistry.session(for: fingerCount), !session.isGestureRejected else { return }
            guard let activeGesture = session.resolvedGesture ?? matchedGesture else { return }

            if direction != activeGesture.kind {
                if let matchedGesture {
                    switchSwipeGesture(fingerCount: fingerCount, to: matchedGesture, distance: swipe.distance)
                } else if direction == oppositeDirectionalSwipeKind(of: activeGesture.kind) {
                    handleSwipeReversal(
                        fingerCount: fingerCount,
                        currentGesture: activeGesture,
                        oppositeGesture: oppositeDirectionalSwipeGesture(of: activeGesture, in: entry.directionalGestures),
                        distance: swipe.distance
                    )
                } else {
                    cancelSwipeGesture(fingerCount: fingerCount)
                }
                return
            }

            session.commitSwipe(
                distance: swipe.distance,
                newKey: .gesture(activeGesture.id),
                step: swipeCycleStepSize
            ) { reverse in
                triggerSingleAction(from: activeGesture, reverse: reverse)
            }

        case .ended, .cancelled:
            resetLoopState(for: fingerCount)

        default:
            break
        }
    }

    private func handleMagnify(_ magnify: SubsurfaceGestureEvent.MagnifyEvent, fingerCount: Int) async {
        guard let entry = recognizerRegistry.entry(for: fingerCount) else { return }

        // Radial menu magnify triggers the center action regardless of direction.
        if let radialMenuGesture = entry.radialMenuGesture {
            await handleRadialMenuMagnify(magnify, fingerCount: fingerCount, gesture: radialMenuGesture)
            return
        }

        switch magnify.phase {
        case .began, .changed:
            if magnify.phase == .began,
               recognizerRegistry.session(for: fingerCount)?.hasGestureBegun != true {
                recognizerRegistry.session(for: fingerCount)?.reset()
            }
            guard let session = recognizerRegistry.session(for: fingerCount), !session.isGestureRejected else { return }

            if !session.hasGestureBegun {
                let initialGesture = magnify.distance >= magnify.originDistance ? entry.magnifyOutGesture : entry.magnifyInGesture
                guard let initialGesture else {
                    return
                }
                handleGestureBegan(fingerCount: fingerCount, gesture: initialGesture)
                recognizerRegistry.session(for: fingerCount)?.setResolvedGesture(initialGesture)
            }

            guard let session = recognizerRegistry.session(for: fingerCount), !session.isGestureRejected,
                  let activeGesture = session.resolvedGesture else {
                return
            }
            guard await activateGestureIfNeeded(
                fingerCount: fingerCount,
                magnifyDisplacement: magnify.distance - magnify.originDistance,
                magnifyActivationThreshold: magnifyCycleStepSize
            ) else {
                return
            }
            guard let session = recognizerRegistry.session(for: fingerCount), !session.isGestureRejected else { return }

            if magnifyReversalDetected(currentGesture: activeGesture, magnify: magnify) {
                let opposite = activeGesture.kind == .magnifyIn ? entry.magnifyOutGesture : entry.magnifyInGesture
                handleMagnifyReversal(
                    fingerCount: fingerCount,
                    currentGesture: activeGesture,
                    oppositeGesture: opposite,
                    distance: magnify.distance
                )
                return
            }

            session.commitMagnify(
                distance: magnify.distance,
                originDistance: magnify.originDistance,
                newKey: .gesture(activeGesture.id),
                step: magnifyCycleStepSize,
                canRepeat: canRepeatGestureAction(activeGesture)
            ) { reverse in
                triggerSingleAction(from: activeGesture, reverse: reverse)
            }

            if let window = session.pendingTargetWindow,
               resolvedWindowAction(from: activeGesture)?.canRepeat == true {
                targetResolver.rememberRepeatableWindow(window, canRepeat: true)
            }

        case .ended, .cancelled:
            resetLoopState(for: fingerCount)

        default:
            break
        }
    }

    /// Magnify within a radial menu gesture triggers the center (last) radial menu action.
    private func handleRadialMenuMagnify(
        _ magnify: SubsurfaceGestureEvent.MagnifyEvent,
        fingerCount: Int,
        gesture: GestureBinding
    ) async {
        switch magnify.phase {
        case .began, .changed:
            if magnify.phase == .began, recognizerRegistry.session(for: fingerCount)?.hasGestureBegun != true {
                handleGestureBegan(fingerCount: fingerCount, gesture: gesture)
            }
            guard await activateGestureIfNeeded(
                fingerCount: fingerCount,
                magnifyDisplacement: magnify.distance - magnify.originDistance
            ) else { return }
            guard let session = recognizerRegistry.session(for: fingerCount), !session.isGestureRejected else { return }

            let actions = radialMenuActions
            guard !actions.isEmpty else { return }
            let centerActionIndex = actions.count - 1

            session.commitRadialMagnify(
                distance: magnify.distance,
                originDistance: magnify.originDistance,
                step: magnifyCycleStepSize
            ) { reverse in
                triggerRadialMenuAction(at: centerActionIndex, from: actions[...], reverse: reverse)
            }

        case .ended, .cancelled:
            resetLoopState(for: fingerCount)

        default:
            break
        }
    }

    /// Resolves the target window and starts blocking trackpad events. Loop itself
    /// isn't opened until the gesture crosses the activation threshold in a `.changed` event.
    private func handleGestureBegan(fingerCount: Int, gesture: GestureBinding) {
        let canRepeat = resolvedWindowAction(from: gesture)?.canRepeat == true
        let window = targetResolver.targetWindow(for: gesture, canRepeat: canRepeat)

        let loopWasAlreadyOpen = checkIfLoopOpen()

        guard let session = recognizerRegistry.session(for: fingerCount) else { return }
        guard session.begin(gesture: gesture, targetWindow: window, loopWasAlreadyOpen: loopWasAlreadyOpen) else {
            return
        }

        targetResolver.rememberRepeatableWindow(window, canRepeat: canRepeat)

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
    private func activateGestureIfNeeded(
        fingerCount: Int,
        magnifyDisplacement: CGFloat? = nil,
        magnifyActivationThreshold: CGFloat? = nil
    ) async -> Bool {
        guard let session = recognizerRegistry.session(for: fingerCount), !session.isGestureRejected else { return false }
        if session.hasActivated { return true }

        if let magnifyDisplacement,
           abs(magnifyDisplacement) < (magnifyActivationThreshold ?? self.magnifyActivationThreshold) {
            return false
        }

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

    private func resetLoopState(for fingerCount: Int, forceClose: Bool = false) {
        if recognizerRegistry.session(for: fingerCount)?.didOpenLoopWithThisGesture == true {
            closeCallback(forceClose)
        }

        gestureBlocker.stop()
        recognizerRegistry.session(for: fingerCount)?.reset()
    }

    private func magnifyReversalDetected(
        currentGesture: GestureBinding,
        magnify: SubsurfaceGestureEvent.MagnifyEvent
    ) -> Bool {
        switch currentGesture.kind {
        case .magnifyIn:
            magnify.distance >= magnify.originDistance
        case .magnifyOut:
            magnify.distance <= magnify.originDistance
        default:
            false
        }
    }

    private func oppositeDirectionalSwipeGesture(
        of current: GestureBinding,
        in directionals: [GestureBinding]
    ) -> GestureBinding? {
        guard let opposite = oppositeDirectionalSwipeKind(of: current.kind) else { return nil }
        return directionals.first { $0.kind == opposite }
    }

    private func oppositeDirectionalSwipeKind(of kind: GestureBinding.Kind) -> GestureBinding.Kind? {
        switch kind {
        case .swipeUp:
            .swipeDown
        case .swipeDown:
            .swipeUp
        case .swipeLeft:
            .swipeRight
        case .swipeRight:
            .swipeLeft
        default:
            nil
        }
    }

    private func isCycleAction(_ gesture: GestureBinding) -> Bool {
        resolvedWindowAction(from: gesture)?.direction == .cycle
    }

    private func canRepeatGestureAction(_ gesture: GestureBinding) -> Bool {
        guard let action = resolvedWindowAction(from: gesture) else { return false }
        return action.canRepeat || action.direction == .cycle
    }

    private func switchSwipeGesture(
        fingerCount: Int,
        to gesture: GestureBinding,
        distance: CGFloat
    ) {
        guard let session = recognizerRegistry.session(for: fingerCount) else { return }
        session.switchSwipeGesture(to: gesture, distance: distance)
        triggerSingleAction(from: gesture, reverse: false)

        if let window = session.pendingTargetWindow,
           resolvedWindowAction(from: gesture)?.canRepeat == true {
            targetResolver.rememberRepeatableWindow(window, canRepeat: true)
        }
    }

    private func cancelSwipeGesture(fingerCount: Int) {
        resetLoopState(for: fingerCount, forceClose: true)
    }

    private func cancelMagnifyGesture(
        fingerCount: Int
    ) {
        resetLoopState(for: fingerCount, forceClose: true)
    }

    private func handleSwipeReversal(
        fingerCount: Int,
        currentGesture: GestureBinding,
        oppositeGesture: GestureBinding?,
        distance: CGFloat
    ) {
        if let oppositeGesture {
            guard let session = recognizerRegistry.session(for: fingerCount) else { return }
            session.switchSwipeGesture(to: oppositeGesture, distance: distance)
            triggerSingleAction(from: oppositeGesture, reverse: false)

            if let window = session.pendingTargetWindow,
               resolvedWindowAction(from: oppositeGesture)?.canRepeat == true {
                targetResolver.rememberRepeatableWindow(window, canRepeat: true)
            }
        } else if isCycleAction(currentGesture) {
            triggerSingleAction(from: currentGesture, reverse: true)
            recognizerRegistry.session(for: fingerCount)?.updateLastCommitSwipeDistance(distance)
        } else {
            cancelSwipeGesture(fingerCount: fingerCount)
        }
    }

    private func handleMagnifyReversal(
        fingerCount: Int,
        currentGesture: GestureBinding,
        oppositeGesture: GestureBinding?,
        distance: CGFloat
    ) {
        if let oppositeGesture {
            guard let session = recognizerRegistry.session(for: fingerCount) else { return }
            // Direction is fixed by the new gesture's gesture type, not by current finger distance,
            // since the user may not yet have crossed neutral when reversing
            let direction = oppositeGesture.kind == .magnifyOut ? 1 : -1
            session.switchMagnifyGesture(to: oppositeGesture, distance: distance, direction: direction)
            triggerSingleAction(from: oppositeGesture, reverse: false)

            if let window = session.pendingTargetWindow,
               resolvedWindowAction(from: oppositeGesture)?.canRepeat == true {
                targetResolver.rememberRepeatableWindow(window, canRepeat: true)
            }
        } else if isCycleAction(currentGesture) {
            triggerSingleAction(from: currentGesture, reverse: true)
            recognizerRegistry.session(for: fingerCount)?.updateLastCommitMagnifyDistance(distance)
        } else {
            cancelMagnifyGesture(fingerCount: fingerCount)
        }
    }

    private func triggerRadialMenuAction(at index: Int, from actions: ArraySlice<RadialMenuAction>, reverse: Bool = false) {
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

    private func resolvedWindowAction(from gesture: GestureBinding) -> WindowAction? {
        guard case let .singleAction(actionType) = gesture.action else { return nil }
        switch actionType {
        case let .custom(action): return action
        case let .keybindReference(id): return resolveKeybindReference(id)
        }
    }

    private func triggerSingleAction(from gesture: GestureBinding, reverse: Bool = false) {
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

    private func matchDirectionalSwipeGesture(kind: GestureBinding.Kind, from gestures: [GestureBinding]) -> GestureBinding? {
        gestures.first { $0.kind == kind }
    }

    private func directionalSwipeKind(angle: CGFloat) -> GestureBinding.Kind {
        let normalizedAngle = normalizedAngle(fromSubsurfaceAngle: angle)

        if normalizedAngle >= 7 * .pi / 4 || normalizedAngle < .pi / 4 {
            return .swipeUp
        } else if normalizedAngle >= .pi / 4, normalizedAngle < 3 * .pi / 4 {
            return .swipeRight
        } else if normalizedAngle >= 3 * .pi / 4, normalizedAngle < 5 * .pi / 4 {
            return .swipeDown
        } else {
            return .swipeLeft
        }
    }

    private func normalizedAngle(fromSubsurfaceAngle angle: CGFloat) -> CGFloat {
        // Subsurface emits y-up angles (counterclockwise from +x); Loop uses 0 = up, growing clockwise.
        let angleFromOrigin = .pi / 2 - angle
        var normalizedAngle = angleFromOrigin
        if normalizedAngle < 0 { normalizedAngle += 2 * .pi }
        return normalizedAngle
    }

    private func indexWithCardinalBias(angle: CGFloat, actionCount: Int, cardinalBias: CGFloat = 0.1) -> Int {
        let baseAngleSpan = (.pi * 2) / CGFloat(actionCount)
        let halfAngleSpan = baseAngleSpan / 2.0

        let adjustedAngle = (angle + halfAngleSpan).truncatingRemainder(dividingBy: .pi * 2)
        let rawSegment = Int(adjustedAngle / baseAngleSpan) % actionCount

        let segmentAngle = adjustedAngle.truncatingRemainder(dividingBy: baseAngleSpan)
        let normalizedPosition = segmentAngle / baseAngleSpan

        let isCurrentCardinal = rawSegment % 2 == 0

        if isCurrentCardinal {
            return rawSegment
        } else {
            if normalizedPosition < cardinalBias / 2 {
                return (rawSegment - 1 + actionCount) % actionCount
            } else if normalizedPosition > 1.0 - cardinalBias / 2 {
                return (rawSegment + 1) % actionCount
            } else {
                return rawSegment
            }
        }
    }
}
