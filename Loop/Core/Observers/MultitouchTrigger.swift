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
    private let openCallback: (WindowAction, Window) async throws -> ()
    private let closeCallback: (Bool) -> ()
    private let changeAction: (WindowAction, Bool) -> ()
    private let checkIfLoopOpen: () -> Bool

    private let gestureMonitor = SubsurfaceMonitor()
    private let gestureBlocker: MultitouchGestureBlocker = .init()

    private var recognizers: [Int: RecognizerEntry] = [:]
    private var gesturesObservationTask: Task<(), Never>?
    private var systemGestureReconciliationTask: Task<(), Never>?
    private var isStarted = false

    /// Window most recently targeted by a `canRepeat` gesture gesture.
    /// Allows the user keep shrinking/growing a window after the cursor has fallen off its (now smaller) frame.
    private var lastRepeatableWindow: Window?

    private let panCycleStepSize: CGFloat = 0.15
    private let zoomActivationThreshold: CGFloat = 0.3
    private let zoomCycleStepSize: CGFloat = 0.15

    private var radialMenuActions: [RadialMenuAction] {
        RadialMenuAction.userConfiguredActions
    }

    private static let failedToResolveKeybindAction: WindowAction = .init(.noAction)

    private enum ActionKey: Hashable {
        case radialSlot(Int)
        case radialCenter
        case gesture(UUID)
    }

    private struct GestureState {
        var didOpenLoopWithThisGesture = false
        var isGestureRejected = false
        var hasActivated = false
        var hasGestureBegun = false
        /// The gesture currently driving this stroke. Swapped on direction reversal
        var resolvedGesture: Gesture?
        var pendingTargetWindow: Window?
        var lastCommittedAction: ActionKey?
        var lastCommitPanDistance: CGFloat = 0
        var lastCommitPinchDistance: CGFloat = 0
        var pinchDirection: Int = 0
    }

    /// Snapshot of the gestures that apply at this finger count, so handlers
    /// don't fire actions against a gesture the user has just deleted.
    private struct RecognizerEntry {
        let recognizer: SubsurfaceGestureRecognizer
        var task: Task<(), Never>?
        var state: GestureState
        var radialMenuGesture: Gesture?
        var directionalGestures: [Gesture]
        var pinchGesture: Gesture?
        var spreadGesture: Gesture?

        static func categorize(
            _ gestures: [Gesture]
        ) -> (radial: Gesture?, directionals: [Gesture], pinch: Gesture?, spread: Gesture?) {
            let radial = gestures.first { $0.kind == .radialMenu }
            let directionals = gestures.filter(\.kind.isDirectionalPan)
            let pinch = gestures.first { $0.kind == .pinch }
            let spread = gestures.first { $0.kind == .spread }
            return (radial, directionals, pinch, spread)
        }
    }

    init(
        windowActionCache: WindowActionCache,
        openCallback: @escaping (WindowAction, Window) async throws -> (),
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

        gesturesObservationTask = Task { [weak self] in
            // Watch keybinds too, so gestures referencing a deleted or no-action keybind get filtered out by `rebuildRecognizers`
            for await _ in Defaults.updates(.gestures, .keybinds) {
                guard !Task.isCancelled, let self else { break }
                rebuildRecognizers()
            }
        }
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false

        reconcileSystemGestures()
        gesturesObservationTask?.cancel()
        gesturesObservationTask = nil

        for fingerCount in Array(recognizers.keys) {
            stopRecognizer(for: fingerCount)
        }
        recognizers.removeAll()

        gestureMonitor.stop()
        lastRepeatableWindow = nil
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
        let allGestures = Defaults[.gestures]
        let enabledGestures = allGestures.filter { !$0.isDisabled }
        let conflictingIDs = Gesture.conflictingEnabledIDs(in: allGestures)
        let activeGestures = enabledGestures.filter { !conflictingIDs.contains($0.id) }
        let gesturesByFingerCount = Dictionary(grouping: activeGestures, by: \.fingerCount)
        let neededFingerCounts = Set(gesturesByFingerCount.keys)

        // Remove stale recognizers
        for fingerCount in Array(recognizers.keys) where !neededFingerCounts.contains(fingerCount) {
            stopRecognizer(for: fingerCount)
            recognizers.removeValue(forKey: fingerCount)
        }

        // Add new recognizers or refresh cached gestures on existing ones.
        for (fingerCount, gestures) in gesturesByFingerCount {
            let (radial, directionals, pinch, spread) = RecognizerEntry.categorize(gestures)
            if recognizers[fingerCount] == nil {
                startRecognizer(for: fingerCount, radial: radial, directionals: directionals, pinch: pinch, spread: spread)
            } else {
                recognizers[fingerCount]?.radialMenuGesture = radial
                recognizers[fingerCount]?.directionalGestures = directionals
                recognizers[fingerCount]?.pinchGesture = pinch
                recognizers[fingerCount]?.spreadGesture = spread
            }
        }
    }

    private func startRecognizer(
        for fingerCount: Int,
        radial: Gesture?,
        directionals: [Gesture],
        pinch: Gesture?,
        spread: Gesture?
    ) {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: fingerCount)
        recognizers[fingerCount] = RecognizerEntry(
            recognizer: recognizer,
            task: nil,
            state: GestureState(),
            radialMenuGesture: radial,
            directionalGestures: directionals,
            pinchGesture: pinch,
            spreadGesture: spread
        )

        let task = Task { [weak self] in
            guard let self else { return }
            for await event in recognizer.events(from: gestureMonitor) {
                guard !Task.isCancelled else { break }
                switch event {
                case let .pan(pan):
                    await handlePan(pan, fingerCount: fingerCount)
                case let .pinch(pinch):
                    await handlePinch(pinch, fingerCount: fingerCount)
                case .determining, .rotation:
                    break
                }
            }
        }
        recognizers[fingerCount]?.task = task
    }

    private func stopRecognizer(for fingerCount: Int) {
        guard let entry = recognizers[fingerCount] else { return }
        entry.task?.cancel()
        entry.recognizer.reset()
        if entry.state.didOpenLoopWithThisGesture {
            closeCallback(false)
        }
        gestureBlocker.stop()
    }

    private func handlePan(_ pan: SubsurfaceGestureEvent.PanEvent, fingerCount: Int) async {
        guard let entry = recognizers[fingerCount] else { return }

        if let radialMenuGesture = entry.radialMenuGesture {
            await handleRadialMenuPan(pan, fingerCount: fingerCount, gesture: radialMenuGesture)
        } else if let directionalGesture = matchDirectionalPanGesture(angle: pan.angle, from: entry.directionalGestures) {
            await handleDirectionalPan(pan, fingerCount: fingerCount, gesture: directionalGesture)
        }
    }

    private func handleRadialMenuPan(
        _ pan: SubsurfaceGestureEvent.PanEvent,
        fingerCount: Int,
        gesture: Gesture
    ) async {
        switch pan.phase {
        case .began, .changed:
            if pan.phase == .began {
                handleGestureBegan(fingerCount: fingerCount, gesture: gesture)
            }
            guard await activateGestureIfNeeded(fingerCount: fingerCount) else { return }
            guard var state = recognizers[fingerCount]?.state, !state.isGestureRejected else { return }

            // Subsurface emits y-up angles (counterclockwise from +x); the radial
            // menu wants 0 = up, growing clockwise. Mirror via `pi/2 - angle`.
            let angleFromOrigin = .pi / 2 - pan.angle
            var normalizedAngle = angleFromOrigin
            if normalizedAngle < 0 { normalizedAngle += 2 * .pi }

            let actions = radialMenuActions.dropLast()
            guard actions.count > 1 else { return }

            let newIndex: Int
            if actions.count == 8 {
                newIndex = indexWithCardinalBias(angle: normalizedAngle, actionCount: actions.count)
            } else {
                let actionAngleSpan = (.pi * 2) / CGFloat(actions.count)
                let halfAngleSpan = actionAngleSpan / 2.0
                newIndex = Int((normalizedAngle + halfAngleSpan) / actionAngleSpan) % actions.count
            }

            commitPan(
                &state,
                distance: pan.distance,
                newKey: .radialSlot(newIndex),
                fingerCount: fingerCount
            ) { reverse in
                triggerRadialMenuAction(at: newIndex, from: actions, reverse: reverse)
            }

        case .ended, .cancelled:
            resetLoopState(for: fingerCount)

        default:
            break
        }
    }

    private func handleDirectionalPan(
        _ pan: SubsurfaceGestureEvent.PanEvent,
        fingerCount: Int,
        gesture: Gesture
    ) async {
        guard let entry = recognizers[fingerCount] else { return }

        switch pan.phase {
        case .began, .changed:
            if pan.phase == .began {
                handleGestureBegan(fingerCount: fingerCount, gesture: gesture)
                recognizers[fingerCount]?.state.resolvedGesture = gesture
            }
            guard await activateGestureIfNeeded(fingerCount: fingerCount) else { return }
            guard var state = recognizers[fingerCount]?.state, !state.isGestureRejected else { return }

            let activeGesture = state.resolvedGesture ?? gesture

            if panReversalDetected(state, distance: pan.distance) {
                handlePanReversal(
                    fingerCount: fingerCount,
                    currentGesture: activeGesture,
                    oppositeGesture: oppositeDirectionalPanGesture(of: activeGesture, in: entry.directionalGestures),
                    distance: pan.distance
                )
                return
            }

            commitPan(
                &state,
                distance: pan.distance,
                newKey: .gesture(activeGesture.id),
                fingerCount: fingerCount
            ) { reverse in
                triggerSingleAction(from: activeGesture, reverse: reverse)
            }

        case .ended, .cancelled:
            resetLoopState(for: fingerCount)

        default:
            break
        }
    }

    private func handlePinch(_ pinch: SubsurfaceGestureEvent.PinchEvent, fingerCount: Int) async {
        guard let entry = recognizers[fingerCount] else { return }

        // Radial menu pinch triggers the center action regardless of direction
        if let radialMenuGesture = entry.radialMenuGesture {
            await handleRadialMenuPinch(pinch, fingerCount: fingerCount, gesture: radialMenuGesture)
            return
        }

        switch pinch.phase {
        case .began:
            // Direction unknown, reset state but defer handleGestureBegan until first .changed
            recognizers[fingerCount]?.state = GestureState()

        case .changed:
            guard var state = recognizers[fingerCount]?.state, !state.isGestureRejected else { return }

            if !state.hasGestureBegun {
                let initialGesture = pinch.distance >= pinch.originDistance ? entry.spreadGesture : entry.pinchGesture
                guard let initialGesture else {
                    state.isGestureRejected = true
                    recognizers[fingerCount]?.state = state
                    return
                }
                handleGestureBegan(fingerCount: fingerCount, gesture: initialGesture)
                recognizers[fingerCount]?.state.hasGestureBegun = true
                recognizers[fingerCount]?.state.resolvedGesture = initialGesture
            }

            guard let state = recognizers[fingerCount]?.state, !state.isGestureRejected,
                  let activeGesture = state.resolvedGesture else { return }
            guard await activateGestureIfNeeded(
                fingerCount: fingerCount,
                pinchDisplacement: pinch.distance - pinch.originDistance
            ) else { return }
            guard var state = recognizers[fingerCount]?.state, !state.isGestureRejected else { return }

            if pinchReversalDetected(state, distance: pinch.distance) {
                let opposite = activeGesture.kind == .pinch ? entry.spreadGesture : entry.pinchGesture
                handlePinchReversal(
                    fingerCount: fingerCount,
                    currentGesture: activeGesture,
                    oppositeGesture: opposite,
                    distance: pinch.distance
                )
                return
            }

            commitPinch(
                &state,
                distance: pinch.distance,
                originDistance: pinch.originDistance,
                newKey: .gesture(activeGesture.id),
                fingerCount: fingerCount
            ) { reverse in
                triggerSingleAction(from: activeGesture, reverse: reverse)
            }

            if let window = recognizers[fingerCount]?.state.pendingTargetWindow,
               resolvedWindowAction(from: activeGesture)?.canRepeat == true {
                lastRepeatableWindow = window
            }

        case .ended, .cancelled:
            resetLoopState(for: fingerCount)

        default:
            break
        }
    }

    /// Pinch within a radial menu gesture, triggers the center (last) radial menu action.
    private func handleRadialMenuPinch(
        _ pinch: SubsurfaceGestureEvent.PinchEvent,
        fingerCount: Int,
        gesture: Gesture
    ) async {
        switch pinch.phase {
        case .began, .changed:
            if pinch.phase == .began {
                handleGestureBegan(fingerCount: fingerCount, gesture: gesture)
            }
            guard await activateGestureIfNeeded(
                fingerCount: fingerCount,
                pinchDisplacement: pinch.distance - pinch.originDistance
            ) else { return }
            guard var state = recognizers[fingerCount]?.state, !state.isGestureRejected else { return }

            let actions = radialMenuActions
            guard !actions.isEmpty else { return }
            let centerActionIndex = actions.count - 1

            commitRadialPinch(
                &state,
                distance: pinch.distance,
                originDistance: pinch.originDistance,
                fingerCount: fingerCount
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
    private func handleGestureBegan(fingerCount: Int, gesture: Gesture) {
        var window = findTargetWindow(for: gesture)
        if window == nil, resolvedWindowAction(from: gesture)?.canRepeat == true {
            window = lastRepeatableWindow
        }

        let loopWasAlreadyOpen = checkIfLoopOpen()

        guard window != nil || loopWasAlreadyOpen else {
            recognizers[fingerCount]?.state.isGestureRejected = true
            return
        }

        if let window, resolvedWindowAction(from: gesture)?.canRepeat == true {
            lastRepeatableWindow = window
        }

        var state = GestureState()
        state.pendingTargetWindow = window
        // Loop is already on screen, so no activation threshold to cross.
        state.hasActivated = loopWasAlreadyOpen
        recognizers[fingerCount]?.state = state
        gestureBlocker.start()
    }

    /// Opens Loop on the target window resolved at `.began`. Pinch and spread gestures
    /// gate on their respective activation thresholds; pan gestures activate on the first
    /// `.began` event Subsurface emits.
    private func activateGestureIfNeeded(
        fingerCount: Int,
        pinchDisplacement: CGFloat? = nil
    ) async -> Bool {
        guard var state = recognizers[fingerCount]?.state, !state.isGestureRejected else { return false }
        if state.hasActivated { return true }

        if let pinchDisplacement, abs(pinchDisplacement) < zoomActivationThreshold {
            return false
        }

        if let window = state.pendingTargetWindow {
            do {
                try await openCallback(.init(.noSelection), window)
                state.didOpenLoopWithThisGesture = true
            } catch {
                state.isGestureRejected = true
                recognizers[fingerCount]?.state = state
                gestureBlocker.stop()
                return false
            }
        }

        state.hasActivated = true
        recognizers[fingerCount]?.state = state
        return true
    }

    private func resetLoopState(for fingerCount: Int) {
        if recognizers[fingerCount]?.state.didOpenLoopWithThisGesture == true {
            closeCallback(false)
        }

        gestureBlocker.stop()
        recognizers[fingerCount]?.state = GestureState()
    }

    private func findTargetWindow(for gesture: Gesture) -> Window? {
        let cursorPosition = NSEvent.mouseLocation.flipY(screen: NSScreen.screens[0])

        guard let window = WindowUtility.windowAtPosition(cursorPosition) else {
            return nil
        }

        // 2-finger gestures are always titlebar-only to avoid system gesture conflicts.
        switch gesture.fingerCount <= 2 ? .titlebar : gesture.activationZone {
        case .titlebar:
            let minimumTitlebarHeight = Defaults[.gestureTitlebarHeight]
            let titlebarHeight: CGFloat = if #available(macOS 26, *) {
                if #unavailable(macOS 27),
                   let cornerRadius = SkyLightToolBelt.getCornerRadii(windowID: window.cgWindowID)?.topLeading {
                    max(2 * cornerRadius, minimumTitlebarHeight)
                } else {
                    minimumTitlebarHeight
                }
            } else {
                minimumTitlebarHeight
            }

            log.info("Detected titlebar height of \(titlebarHeight)")

            let titlebarMinY = window.frame.minY
            let titlebarMaxY = window.frame.minY + titlebarHeight
            let isInTitlebar = cursorPosition.y >= titlebarMinY && cursorPosition.y <= titlebarMaxY
            return isInTitlebar ? window : nil

        case .anywhere:
            return window
        }
    }

    /// Commit distance only advances when an action fires, so sub-step
    /// jitter can't drift it past the reverse threshold. Activation is gated
    /// upstream by `activateGestureIfNeeded`, so the first commit fires
    /// immediately to seed Loop's initial active action.
    private func commitPan(
        _ state: inout GestureState,
        distance: CGFloat,
        newKey: ActionKey,
        fingerCount: Int,
        fire: (_ reverse: Bool) -> ()
    ) {
        if state.lastCommittedAction == newKey {
            let delta = distance - state.lastCommitPanDistance
            if delta >= panCycleStepSize {
                state.lastCommitPanDistance = distance
                recognizers[fingerCount]?.state = state
                fire(false)
            } else if delta <= -panCycleStepSize {
                state.lastCommitPanDistance = distance
                recognizers[fingerCount]?.state = state
                fire(true)
            }
        } else {
            state.lastCommittedAction = newKey
            state.lastCommitPanDistance = distance
            recognizers[fingerCount]?.state = state
            fire(false)
        }
    }

    private func commitRadialPinch(
        _ state: inout GestureState,
        distance: CGFloat,
        originDistance: CGFloat,
        fingerCount: Int,
        fire: (_ reverse: Bool) -> ()
    ) {
        if state.lastCommittedAction != .radialCenter {
            state.lastCommittedAction = .radialCenter
            state.lastCommitPinchDistance = distance
            recognizers[fingerCount]?.state = state
            fire(distance < originDistance)
            return
        }

        let delta = distance - state.lastCommitPinchDistance
        if delta >= zoomCycleStepSize {
            state.lastCommitPinchDistance = distance
            recognizers[fingerCount]?.state = state
            fire(false)
        } else if delta <= -zoomCycleStepSize {
            state.lastCommitPinchDistance = distance
            recognizers[fingerCount]?.state = state
            fire(true)
        }
    }

    private func commitPinch(
        _ state: inout GestureState,
        distance: CGFloat,
        originDistance: CGFloat,
        newKey: ActionKey,
        fingerCount: Int,
        fire: (_ reverse: Bool) -> ()
    ) {
        if state.lastCommittedAction != newKey {
            state.pinchDirection = distance >= originDistance ? 1 : -1
            state.lastCommittedAction = newKey
            state.lastCommitPinchDistance = distance
            recognizers[fingerCount]?.state = state
            fire(false)
            return
        }

        let delta = (distance - state.lastCommitPinchDistance) * CGFloat(state.pinchDirection)
        if delta >= zoomCycleStepSize {
            state.lastCommitPinchDistance = distance
            recognizers[fingerCount]?.state = state
            fire(false)
        } else if delta <= -zoomCycleStepSize {
            state.lastCommitPinchDistance = distance
            recognizers[fingerCount]?.state = state
            fire(true)
        }
    }

    private func panReversalDetected(_ state: GestureState, distance: CGFloat) -> Bool {
        state.lastCommittedAction != nil
            && (distance - state.lastCommitPanDistance) <= -panCycleStepSize
    }

    private func pinchReversalDetected(_ state: GestureState, distance: CGFloat) -> Bool {
        guard state.lastCommittedAction != nil, state.pinchDirection != 0 else { return false }
        let delta = (distance - state.lastCommitPinchDistance) * CGFloat(state.pinchDirection)
        return delta <= -zoomCycleStepSize
    }

    private func oppositeDirectionalPanGesture(
        of current: Gesture,
        in directionals: [Gesture]
    ) -> Gesture? {
        let opposite: Gesture.Kind? = switch current.kind {
        case .panUp: .panDown
        case .panDown: .panUp
        case .panLeft: .panRight
        case .panRight: .panLeft
        default: nil
        }
        guard let opposite else { return nil }
        return directionals.first { $0.kind == opposite }
    }

    private func isCycleAction(_ gesture: Gesture) -> Bool {
        resolvedWindowAction(from: gesture)?.direction == .cycle
    }

    private func handlePanReversal(
        fingerCount: Int,
        currentGesture: Gesture,
        oppositeGesture: Gesture?,
        distance: CGFloat
    ) {
        if let oppositeGesture {
            guard var state = recognizers[fingerCount]?.state else { return }
            state.resolvedGesture = oppositeGesture
            state.lastCommittedAction = .gesture(oppositeGesture.id)
            state.lastCommitPanDistance = distance
            recognizers[fingerCount]?.state = state
            triggerSingleAction(from: oppositeGesture, reverse: false)

            if let window = state.pendingTargetWindow,
               resolvedWindowAction(from: oppositeGesture)?.canRepeat == true {
                lastRepeatableWindow = window
            }
        } else if isCycleAction(currentGesture) {
            triggerSingleAction(from: currentGesture, reverse: true)
            recognizers[fingerCount]?.state.lastCommitPanDistance = distance
        }
    }

    private func handlePinchReversal(
        fingerCount: Int,
        currentGesture: Gesture,
        oppositeGesture: Gesture?,
        distance: CGFloat
    ) {
        if let oppositeGesture {
            guard var state = recognizers[fingerCount]?.state else { return }
            // Direction is fixed by the new gesture's gesture type, not by current finger distance,
            // since the user may not yet have crossed neutral when reversing
            let direction = oppositeGesture.kind == .spread ? 1 : -1
            state.resolvedGesture = oppositeGesture
            state.lastCommittedAction = .gesture(oppositeGesture.id)
            state.pinchDirection = direction
            state.lastCommitPinchDistance = distance
            recognizers[fingerCount]?.state = state
            triggerSingleAction(from: oppositeGesture, reverse: false)

            if let window = state.pendingTargetWindow,
               resolvedWindowAction(from: oppositeGesture)?.canRepeat == true {
                lastRepeatableWindow = window
            }
        } else if isCycleAction(currentGesture) {
            triggerSingleAction(from: currentGesture, reverse: true)
            recognizers[fingerCount]?.state.lastCommitPinchDistance = distance
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

    private func resolvedWindowAction(from gesture: Gesture) -> WindowAction? {
        guard case let .singleAction(actionType) = gesture.action else { return nil }
        switch actionType {
        case let .custom(action): return action
        case let .keybindReference(id): return resolveKeybindReference(id)
        }
    }

    private func triggerSingleAction(from gesture: Gesture, reverse: Bool = false) {
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

    private func matchDirectionalPanGesture(angle: CGFloat, from gestures: [Gesture]) -> Gesture? {
        let angleFromOrigin = .pi / 2 - angle
        var normalizedAngle = angleFromOrigin
        if normalizedAngle < 0 { normalizedAngle += 2 * .pi }

        let direction: Gesture.Kind = if normalizedAngle >= 7 * .pi / 4 || normalizedAngle < .pi / 4 {
            .panUp
        } else if normalizedAngle >= .pi / 4, normalizedAngle < 3 * .pi / 4 {
            .panRight
        } else if normalizedAngle >= 3 * .pi / 4, normalizedAngle < 5 * .pi / 4 {
            .panDown
        } else {
            .panLeft
        }

        return gestures.first { $0.kind == direction }
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
