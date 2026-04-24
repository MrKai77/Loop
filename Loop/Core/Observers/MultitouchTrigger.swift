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

    private let panActivationThreshold: CGFloat = 0.3
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
        var lastCommittedAction: ActionKey?
        var lastCommitPanDistance: CGFloat = 0
        /// Signed by `pinchDirection` so pinch-in advances are positive deltas.
        var lastCommitPinchOffset: CGFloat = 0
        /// `+1` outward, `-1` inward; locked at activation.
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
    }

    func start() {
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
        bindingsObservationTask?.cancel()
        bindingsObservationTask = nil

        for fingerCount in Array(recognizers.keys) {
            stopRecognizer(for: fingerCount)
        }
        recognizers.removeAll()

        gestureMonitor.stop()
    }

    private func rebuildRecognizers() {
        let bindingsByFingerCount = Dictionary(grouping: Defaults[.gestureBindings], by: \.fingerCount)
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
                case .rotation:
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
        case .began:
            await handleGestureBegan(fingerCount: fingerCount, binding: binding)

        case .changed:
            guard var state = recognizers[fingerCount]?.state, !state.isGestureRejected else { return }

            let angleFromOrigin = pan.angle + .pi / 2
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
        case .began:
            await handleGestureBegan(fingerCount: fingerCount, binding: binding)

        case .changed:
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
        case .began:
            await handleGestureBegan(fingerCount: fingerCount, binding: binding)

        case .changed:
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
        case .began:
            await handleGestureBegan(fingerCount: fingerCount, binding: binding)

        case .changed:
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

    private func handleGestureBegan(fingerCount: Int, binding: GestureBinding) async {
        let window = findTargetWindow(for: binding)
        let loopWasAlreadyOpen = checkIfLoopOpen()

        guard window != nil || loopWasAlreadyOpen else {
            recognizers[fingerCount]?.state.isGestureRejected = true
            return
        }

        recognizers[fingerCount]?.state.isGestureRejected = false
        recognizers[fingerCount]?.state.lastCommittedAction = nil
        recognizers[fingerCount]?.state.lastCommitPanDistance = 0
        recognizers[fingerCount]?.state.lastCommitPinchOffset = 0
        recognizers[fingerCount]?.state.pinchDirection = 0
        gestureBlocker.start()

        if let window, !loopWasAlreadyOpen {
            do {
                try await openCallback(.init(.noSelection), window)
                recognizers[fingerCount]?.state.didOpenLoopWithThisGesture = true
            } catch {
                gestureBlocker.stop()
                recognizers[fingerCount]?.state.isGestureRejected = true
            }
        }
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
            let titlebarHeight: CGFloat = Defaults[.gestureTitlebarHeight]
            let titlebarMinY = window.frame.minY
            let titlebarMaxY = window.frame.minY + titlebarHeight
            let isInTitlebar = cursorPosition.y >= titlebarMinY && cursorPosition.y <= titlebarMaxY
            return isInTitlebar ? window : nil

        case .anywhere:
            return window
        }
    }

    /// Commit distance only advances when an action fires, so sub-step
    /// jitter can't drift it past the reverse threshold.
    private func commitPan(
        _ state: inout GestureState,
        distance: CGFloat,
        newKey: ActionKey,
        fingerCount: Int,
        fire: (_ reverse: Bool) -> ()
    ) {
        if state.lastCommittedAction == nil {
            guard distance >= panActivationThreshold else { return }
            state.lastCommittedAction = newKey
            state.lastCommitPanDistance = distance
            recognizers[fingerCount]?.state = state
            fire(false)
            return
        }

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
            guard abs(scale - 1.0) >= pinchActivationThreshold else { return }
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

    private func triggerSingleAction(from binding: GestureBinding, reverse: Bool = false) {
        let resolvedAction: WindowAction

        switch binding.action {
        case .radialMenuActions:
            return
        case let .singleAction(actionType):
            switch actionType {
            case let .custom(windowAction):
                resolvedAction = windowAction
            case let .keybindReference(id):
                resolvedAction = resolveKeybindReference(id)
            }
        }

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
        let angleFromOrigin = angle + .pi / 2
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
