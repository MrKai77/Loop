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
    private var bindingsObservationTask: Task<(), Never>?
    private var systemGestureReconciliationTask: Task<(), Never>?
    private var isStarted = false

    /// Window most recently targeted by a `canRepeat` gesture binding.
    /// Allows the user keep shrinking/growing a window after the cursor has fallen off its (now smaller) frame.
    private var lastRepeatableWindow: Window?

    private let panCycleStepSize: CGFloat = 0.2
    private let pinchActivationThreshold: CGFloat = 0.4
    private let pinchCycleStepSize: CGFloat = 0.7

    private var radialMenuActions: [RadialMenuAction] {
        RadialMenuAction.userConfiguredActions
    }

    private static let failedToResolveKeybindAction: WindowAction = .init(.noAction)

    private enum ActionKey: Hashable {
        case radialSlot(Int)
        case radialCenter
        case binding(UUID)
    }

    private struct GestureState {
        var didOpenLoopWithThisGesture = false
        var isGestureRejected = false
        var hasActivated = false
        var pendingTargetWindow: Window?
        var lastCommittedAction: ActionKey?
        var lastCommitPanDistance: CGFloat = 0
        var lastCommitPinchOffset: CGFloat = 0
        var pinchDirection: Int = 0
    }

    /// Snapshot of the bindings that apply at this finger count, so handlers
    /// don't fire actions against a binding the user has just deleted.
    private struct RecognizerEntry {
        let recognizer: SubsurfaceGestureRecognizer
        var task: Task<(), Never>?
        var state: GestureState
        var radialMenuBinding: GestureBinding?
        var directionalBindings: [GestureBinding]
        var pinchBinding: GestureBinding?

        static func categorize(
            _ bindings: [GestureBinding]
        ) -> (radial: GestureBinding?, directionals: [GestureBinding], pinch: GestureBinding?) {
            let radial = bindings.first { $0.gestureType == .radialMenu }
            let directionals = bindings.filter(\.gestureType.isDirectionalPan)
            let pinch = bindings.first { $0.gestureType == .pinch }
            return (radial, directionals, pinch)
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

        bindingsObservationTask = Task { [weak self] in
            for await _ in Defaults.updates(.gestureBindings) {
                guard !Task.isCancelled, let self else { break }
                rebuildRecognizers()
            }
        }
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false

        reconcileSystemGestures()
        bindingsObservationTask?.cancel()
        bindingsObservationTask = nil

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
                .gestureBindings
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
            bindings: Defaults[.gestureBindings]
        )
    }

    private func rebuildRecognizers() {
        let allBindings = Defaults[.gestureBindings]
        let conflictingIDs = GestureBinding.conflictingIDs(in: allBindings)
        let activeBindings = allBindings.filter { !conflictingIDs.contains($0.id) }
        let bindingsByFingerCount = Dictionary(grouping: activeBindings, by: \.fingerCount)
        let neededFingerCounts = Set(bindingsByFingerCount.keys)

        // Remove stale recognizers
        for fingerCount in Array(recognizers.keys) where !neededFingerCounts.contains(fingerCount) {
            stopRecognizer(for: fingerCount)
            recognizers.removeValue(forKey: fingerCount)
        }

        // Add new recognizers or refresh cached bindings on existing ones.
        for (fingerCount, bindings) in bindingsByFingerCount {
            let (radial, directionals, pinch) = RecognizerEntry.categorize(bindings)
            if recognizers[fingerCount] == nil {
                startRecognizer(for: fingerCount, radial: radial, directionals: directionals, pinch: pinch)
            } else {
                recognizers[fingerCount]?.radialMenuBinding = radial
                recognizers[fingerCount]?.directionalBindings = directionals
                recognizers[fingerCount]?.pinchBinding = pinch
            }
        }
    }

    private func startRecognizer(
        for fingerCount: Int,
        radial: GestureBinding?,
        directionals: [GestureBinding],
        pinch: GestureBinding?
    ) {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: fingerCount)
        recognizers[fingerCount] = RecognizerEntry(
            recognizer: recognizer,
            task: nil,
            state: GestureState(),
            radialMenuBinding: radial,
            directionalBindings: directionals,
            pinchBinding: pinch
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

        if let radialMenuBinding = entry.radialMenuBinding {
            await handleRadialMenuPan(pan, fingerCount: fingerCount, binding: radialMenuBinding)
        } else if let directionalBinding = matchDirectionalPanBinding(angle: pan.angle, from: entry.directionalBindings) {
            await handleDirectionalPan(pan, fingerCount: fingerCount, binding: directionalBinding)
        }
    }

    private func handleRadialMenuPan(
        _ pan: SubsurfaceGestureEvent.PanEvent,
        fingerCount: Int,
        binding: GestureBinding
    ) async {
        switch pan.phase {
        case .began, .changed:
            if pan.phase == .began {
                handleGestureBegan(fingerCount: fingerCount, binding: binding)
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
        binding: GestureBinding
    ) async {
        switch pan.phase {
        case .began, .changed:
            if pan.phase == .began {
                handleGestureBegan(fingerCount: fingerCount, binding: binding)
            }
            guard await activateGestureIfNeeded(fingerCount: fingerCount) else { return }
            guard var state = recognizers[fingerCount]?.state, !state.isGestureRejected else { return }

            commitPan(
                &state,
                distance: pan.distance,
                newKey: .binding(binding.id),
                fingerCount: fingerCount
            ) { reverse in
                triggerSingleAction(from: binding, reverse: reverse)
            }

        case .ended, .cancelled:
            resetLoopState(for: fingerCount)

        default:
            break
        }
    }

    private func handlePinch(_ pinch: SubsurfaceGestureEvent.PinchEvent, fingerCount: Int) async {
        guard let entry = recognizers[fingerCount] else { return }

        // If a radial menu binding exists at this finger count, pinch triggers the center action
        if let radialMenuBinding = entry.radialMenuBinding {
            await handleRadialMenuPinch(pinch, fingerCount: fingerCount, binding: radialMenuBinding)
        } else if let pinchBinding = entry.pinchBinding {
            await handleSingleActionPinch(pinch, fingerCount: fingerCount, binding: pinchBinding)
        }
    }

    /// Pinch within a radial menu binding, triggers the center (last) radial menu action.
    private func handleRadialMenuPinch(
        _ pinch: SubsurfaceGestureEvent.PinchEvent,
        fingerCount: Int,
        binding: GestureBinding
    ) async {
        switch pinch.phase {
        case .began, .changed:
            if pinch.phase == .began {
                handleGestureBegan(fingerCount: fingerCount, binding: binding)
            }
            guard await activateGestureIfNeeded(fingerCount: fingerCount, pinchScale: pinch.scale) else { return }
            guard var state = recognizers[fingerCount]?.state, !state.isGestureRejected else { return }

            let actions = radialMenuActions
            guard !actions.isEmpty else { return }
            let centerActionIndex = actions.count - 1

            commitPinch(
                &state,
                scale: pinch.scale,
                newKey: .radialCenter,
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

    /// Standalone pinch binding, triggers the binding's configured action.
    private func handleSingleActionPinch(
        _ pinch: SubsurfaceGestureEvent.PinchEvent,
        fingerCount: Int,
        binding: GestureBinding
    ) async {
        switch pinch.phase {
        case .began, .changed:
            if pinch.phase == .began {
                handleGestureBegan(fingerCount: fingerCount, binding: binding)
            }
            guard await activateGestureIfNeeded(fingerCount: fingerCount, pinchScale: pinch.scale) else { return }
            guard var state = recognizers[fingerCount]?.state, !state.isGestureRejected else { return }

            commitPinch(
                &state,
                scale: pinch.scale,
                newKey: .binding(binding.id),
                fingerCount: fingerCount
            ) { reverse in
                triggerSingleAction(from: binding, reverse: reverse)
            }

        case .ended, .cancelled:
            resetLoopState(for: fingerCount)

        default:
            break
        }
    }

    /// Resolves the target window and starts blocking trackpad events. Loop itself
    /// isn't opened until the gesture crosses the activation threshold in a `.changed` event.
    private func handleGestureBegan(fingerCount: Int, binding: GestureBinding) {
        var window = findTargetWindow(for: binding)
        if window == nil, resolvedWindowAction(from: binding)?.canRepeat == true {
            window = lastRepeatableWindow
        }

        let loopWasAlreadyOpen = checkIfLoopOpen()

        guard window != nil || loopWasAlreadyOpen else {
            recognizers[fingerCount]?.state.isGestureRejected = true
            return
        }

        if let window, resolvedWindowAction(from: binding)?.canRepeat == true {
            lastRepeatableWindow = window
        }

        var state = GestureState()
        state.pendingTargetWindow = window
        // Loop is already on screen, so no activation threshold to cross.
        state.hasActivated = loopWasAlreadyOpen
        recognizers[fingerCount]?.state = state
        gestureBlocker.start()
    }

    /// Opens Loop on the target window resolved at `.began`. Pinch gestures still
    /// gate on `pinchActivationThreshold`; pan gestures activate on the first
    /// `.began` event Subsurface emits.
    private func activateGestureIfNeeded(
        fingerCount: Int,
        pinchScale: CGFloat? = nil
    ) async -> Bool {
        guard var state = recognizers[fingerCount]?.state, !state.isGestureRejected else { return false }
        if state.hasActivated { return true }

        if let pinchScale, abs(pinchScale - 1.0) < pinchActivationThreshold { return false }

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

    private func findTargetWindow(for binding: GestureBinding) -> Window? {
        let cursorPosition = NSEvent.mouseLocation.flipY(screen: NSScreen.screens[0])

        guard let window = WindowUtility.windowAtPosition(cursorPosition) else {
            return nil
        }

        switch binding.activationZone {
        case .titlebar:
            let minimumTitlebarHeight = Defaults[.gestureTitlebarHeight]

            let titlebarHeight: CGFloat = if #available(macOS 26.0, *),
                                             let cornerRadius = SkyLightToolBelt.getCornerRadii(windowID: window.cgWindowID)?.topLeading {
                max(2 * cornerRadius, minimumTitlebarHeight)
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

    private func commitPinch(
        _ state: inout GestureState,
        scale: CGFloat,
        newKey: ActionKey,
        fingerCount: Int,
        fire: (_ reverse: Bool) -> ()
    ) {
        if state.lastCommittedAction != newKey {
            state.pinchDirection = scale >= 1.0 ? 1 : -1
            state.lastCommittedAction = newKey
            state.lastCommitPinchOffset = (scale - 1.0) * CGFloat(state.pinchDirection)
            recognizers[fingerCount]?.state = state
            fire(false)
            return
        }

        let offset = (scale - 1.0) * CGFloat(state.pinchDirection)
        let delta = offset - state.lastCommitPinchOffset
        if delta >= pinchCycleStepSize {
            state.lastCommitPinchOffset = offset
            recognizers[fingerCount]?.state = state
            fire(false)
        } else if delta <= -pinchCycleStepSize {
            state.lastCommitPinchOffset = offset
            recognizers[fingerCount]?.state = state
            fire(true)
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

    private func resolvedWindowAction(from binding: GestureBinding) -> WindowAction? {
        guard case let .singleAction(actionType) = binding.action else { return nil }
        switch actionType {
        case let .custom(action): return action
        case let .keybindReference(id): return resolveKeybindReference(id)
        }
    }

    private func triggerSingleAction(from binding: GestureBinding, reverse: Bool = false) {
        guard let resolvedAction = resolvedWindowAction(from: binding) else { return }
        changeAction(resolvedAction, reverse)
    }

    private func resolveKeybindReference(_ id: UUID) -> WindowAction {
        if let cached = windowActionCache.actionsByIdentifier[id] {
            return cached
        }
        log.warn("Gesture references keybind \(id) that no longer exists")
        return Self.failedToResolveKeybindAction
    }

    private func matchDirectionalPanBinding(angle: CGFloat, from bindings: [GestureBinding]) -> GestureBinding? {
        let angleFromOrigin = .pi / 2 - angle
        var normalizedAngle = angleFromOrigin
        if normalizedAngle < 0 { normalizedAngle += 2 * .pi }

        let direction: GestureBinding.GestureType = if normalizedAngle >= 7 * .pi / 4 || normalizedAngle < .pi / 4 {
            .panUp
        } else if normalizedAngle >= .pi / 4, normalizedAngle < 3 * .pi / 4 {
            .panRight
        } else if normalizedAngle >= 3 * .pi / 4, normalizedAngle < 5 * .pi / 4 {
            .panDown
        } else {
            .panLeft
        }

        return bindings.first { $0.gestureType == direction }
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
