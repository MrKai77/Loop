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

    private var recognizersByFingerCount: [Int: SubsurfaceGestureRecognizer] = [:]
    private var eventTasksByFingerCount: [Int: Task<(), Never>] = [:]
    private var gestureStatesByFingerCount: [Int: GestureState] = [:]

    private var bindingsObservationTask: Task<(), Never>?

    private let panActivationThreshold: CGFloat = 0.3
    private let panCycleStepSize: CGFloat = 0.1
    private let pinchActivationThreshold: CGFloat = 0.4
    private let pinchCycleStepSize: CGFloat = 0.6

    private var radialMenuActions: [RadialMenuAction] {
        RadialMenuAction.userConfiguredActions
    }

    private static let failedToResolveKeybindAction: WindowAction = .init(.noAction)

    private struct GestureState {
        var didOpenLoopWithThisGesture = false
        var isGestureRejected = false
        var lastTriggeredActionIndex: Int?
        var lastTriggeredDistance: CGFloat = 0
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

        for (fingerCount, _) in eventTasksByFingerCount {
            stopRecognizer(for: fingerCount)
        }

        eventTasksByFingerCount.removeAll()
        recognizersByFingerCount.removeAll()
        gestureStatesByFingerCount.removeAll()

        gestureMonitor.stop()
    }

    private func rebuildRecognizers() {
        let bindings = Defaults[.gestureBindings]
        let neededFingerCounts = Set(bindings.map(\.fingerCount))
        let currentFingerCounts = Set(recognizersByFingerCount.keys)

        // Remove stale recognizers
        for fingerCount in currentFingerCounts.subtracting(neededFingerCounts) {
            stopRecognizer(for: fingerCount)
            recognizersByFingerCount.removeValue(forKey: fingerCount)
            eventTasksByFingerCount.removeValue(forKey: fingerCount)
            gestureStatesByFingerCount.removeValue(forKey: fingerCount)
        }

        // Add new recognizers
        for fingerCount in neededFingerCounts.subtracting(currentFingerCounts) {
            startRecognizer(for: fingerCount)
        }
    }

    private func startRecognizer(for fingerCount: Int) {
        let recognizer = SubsurfaceGestureRecognizer(fingerCount: fingerCount)
        recognizersByFingerCount[fingerCount] = recognizer
        gestureStatesByFingerCount[fingerCount] = GestureState()

        eventTasksByFingerCount[fingerCount] = Task { [weak self] in
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
    }

    private func stopRecognizer(for fingerCount: Int) {
        eventTasksByFingerCount[fingerCount]?.cancel()
        recognizersByFingerCount[fingerCount]?.reset()
        if let state = gestureStatesByFingerCount[fingerCount], state.didOpenLoopWithThisGesture {
            closeCallback(false)
        }
        gestureBlocker.stop()
    }

    private func handlePan(_ pan: SubsurfaceGestureEvent.PanEvent, fingerCount: Int) async {
        let bindings = Defaults[.gestureBindings]
        let panBindings = bindings.filter { $0.gestureType.isPan && $0.fingerCount == fingerCount }

        if let radialMenuBinding = panBindings.first(where: { $0.gestureType == .radialMenu }) {
            await handleRadialMenuPan(pan, fingerCount: fingerCount, binding: radialMenuBinding)
        } else if let directionalBinding = matchDirectionalPanBinding(angle: pan.angle, from: panBindings) {
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
            guard gestureStatesByFingerCount[fingerCount]?.isGestureRejected != true else { return }

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

            let state = gestureStatesByFingerCount[fingerCount] ?? GestureState()
            let isSameAction = state.lastTriggeredActionIndex == newIndex
            let isReversing = isSameAction && pan.distance < state.lastTriggeredDistance - panCycleStepSize

            if isSameAction {
                guard abs(pan.distance - state.lastTriggeredDistance) >= panCycleStepSize else { return }
            }

            gestureStatesByFingerCount[fingerCount]?.lastTriggeredActionIndex = newIndex
            gestureStatesByFingerCount[fingerCount]?.lastTriggeredDistance = pan.distance
            triggerRadialMenuAction(at: newIndex, from: actions, reverse: isReversing)

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
            guard gestureStatesByFingerCount[fingerCount]?.isGestureRejected != true else { return }

            let state = gestureStatesByFingerCount[fingerCount] ?? GestureState()
            let isSameAction = state.lastTriggeredActionIndex == 0
            let isReversing = isSameAction && pan.distance < state.lastTriggeredDistance - panCycleStepSize

            if isSameAction {
                guard abs(pan.distance - state.lastTriggeredDistance) >= panCycleStepSize else { return }
            }

            gestureStatesByFingerCount[fingerCount]?.lastTriggeredActionIndex = 0
            gestureStatesByFingerCount[fingerCount]?.lastTriggeredDistance = pan.distance
            triggerSingleAction(from: binding, reverse: isReversing)

        case .ended, .cancelled:
            resetLoopState(for: fingerCount)

        default:
            break
        }
    }

    private func handlePinch(_ pinch: SubsurfaceGestureEvent.PinchEvent, fingerCount: Int) async {
        let bindings = Defaults[.gestureBindings]

        // If a radial menu binding exists at this finger count, pinch triggers the center action
        if let radialMenuBinding = bindings.first(where: { $0.gestureType == .radialMenu && $0.fingerCount == fingerCount }) {
            await handleRadialMenuPinch(pinch, fingerCount: fingerCount, binding: radialMenuBinding)
        } else if let pinchBinding = bindings.first(where: { $0.gestureType == .pinch && $0.fingerCount == fingerCount }) {
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
            guard gestureStatesByFingerCount[fingerCount]?.isGestureRejected != true else { return }

            let actions = radialMenuActions
            let centerActionIndex = actions.count - 1

            let state = gestureStatesByFingerCount[fingerCount] ?? GestureState()
            let isSameAction = state.lastTriggeredActionIndex == centerActionIndex
            let isReversing = isSameAction && pinch.scale < state.lastTriggeredDistance - pinchCycleStepSize

            if isSameAction {
                guard abs(pinch.scale - state.lastTriggeredDistance) >= pinchCycleStepSize else { return }
            } else {
                guard abs(pinch.scale - 1.0) >= pinchActivationThreshold else { return }
            }

            gestureStatesByFingerCount[fingerCount]?.lastTriggeredActionIndex = centerActionIndex
            gestureStatesByFingerCount[fingerCount]?.lastTriggeredDistance = pinch.scale
            triggerRadialMenuAction(at: centerActionIndex, from: actions[...], reverse: isReversing)

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
            guard gestureStatesByFingerCount[fingerCount]?.isGestureRejected != true else { return }

            let state = gestureStatesByFingerCount[fingerCount] ?? GestureState()
            let isSameAction = state.lastTriggeredActionIndex == 0
            let isReversing = isSameAction && pinch.scale < state.lastTriggeredDistance - pinchCycleStepSize

            if isSameAction {
                guard abs(pinch.scale - state.lastTriggeredDistance) >= pinchCycleStepSize else { return }
            } else {
                guard abs(pinch.scale - 1.0) >= pinchActivationThreshold else { return }
            }

            gestureStatesByFingerCount[fingerCount]?.lastTriggeredActionIndex = 0
            gestureStatesByFingerCount[fingerCount]?.lastTriggeredDistance = pinch.scale
            triggerSingleAction(from: binding, reverse: isReversing)

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
            gestureStatesByFingerCount[fingerCount]?.isGestureRejected = true
            return
        }

        gestureStatesByFingerCount[fingerCount]?.isGestureRejected = false
        gestureStatesByFingerCount[fingerCount]?.lastTriggeredActionIndex = nil
        gestureStatesByFingerCount[fingerCount]?.lastTriggeredDistance = 0
        gestureBlocker.start()

        if let window, !loopWasAlreadyOpen {
            do {
                try await openCallback(.init(.noSelection), window)
                gestureStatesByFingerCount[fingerCount]?.didOpenLoopWithThisGesture = true
            } catch {
                gestureBlocker.stop()
                gestureStatesByFingerCount[fingerCount]?.isGestureRejected = true
            }
        }
    }

    private func resetLoopState(for fingerCount: Int) {
        if gestureStatesByFingerCount[fingerCount]?.didOpenLoopWithThisGesture == true {
            closeCallback(false)
        }

        gestureBlocker.stop()
        gestureStatesByFingerCount[fingerCount] = GestureState()
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

    private func triggerRadialMenuAction(at index: Int, from actions: ArraySlice<RadialMenuAction>, reverse: Bool = false) {
        let action = actions[index]

        let resolvedAction: WindowAction = switch action.type {
        case let .custom(windowAction):
            windowAction
        case let .keybindReference(id):
            windowActionCache.actionsByIdentifier[id] ?? Self.failedToResolveKeybindAction
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
                resolvedAction = windowActionCache.actionsByIdentifier[id] ?? Self.failedToResolveKeybindAction
            }
        }

        changeAction(resolvedAction, reverse)
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
