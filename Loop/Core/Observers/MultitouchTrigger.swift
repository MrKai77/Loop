//
//  MultitouchTrigger.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-30.
//

import Scribe
import Subsurface
import SwiftUI

@Loggable
final class MultitouchTrigger {
    private let windowActionCache: WindowActionCache
    private let openCallback: (WindowAction) -> ()
    private let closeCallback: (Bool) -> ()
    private let changeAction: (WindowAction) -> ()
    private let checkIfLoopOpen: () -> Bool

    struct GestureInfo {
        let position: CGPoint
        let distance: CGFloat
    }

    private var originGestureInfo: GestureInfo?
    private var lastGestureInfo: GestureInfo?
    private var maxTouchesInCurrentGesture: Int = 0
    private var isCurrentGestureRejected = false
    private var didOpenLoopWithThisGesture = false

    private var lastTriggeredActionIndex: Int?
    private var lastTriggeredDistance: CGFloat = 0
    private var lastTriggeredZoomDistance: CGFloat = 0

    private struct PositionHistoryEntry {
        let avgPosition: CGPoint
        let touch1Position: CGPoint
        let touch2Position: CGPoint
        let timestamp: TimeInterval
    }

    private var positionHistory: [PositionHistoryEntry] = []
    private let maxHistoryEntries = 5 // Track last 5 positions for smoothing

    private let initialGestureThreshold: CGFloat = 0.025
    private let gestureRepeatThreshold: CGFloat = 0.25
    private let zoomRepeatThreshold: CGFloat = 0.2

    private var inactivityTask: Task<(), Never>?
    private let gestureBlocker: GestureBlocker = .init()

    private var radialMenuActions: [RadialMenuAction] {
        RadialMenuAction.userConfiguredActions
    }

    private let subtrack = SubsurfaceMonitor()
    private static let failedToResolveKeybindAction: WindowAction = .init(.noAction) // This helps to keep a stable ID

    init(
        windowActionCache: WindowActionCache,
        openCallback: @escaping (WindowAction) -> (),
        closeCallback: @escaping (Bool) -> (),
        changeAction: @escaping (WindowAction) -> (),
        checkIfLoopOpen: @escaping () -> Bool
    ) {
        self.windowActionCache = windowActionCache
        self.openCallback = openCallback
        self.closeCallback = closeCallback
        self.changeAction = changeAction
        self.checkIfLoopOpen = checkIfLoopOpen
    }

    func start() {
        Task {
            for await (_, touchData) in subtrack.contacts() {
                resetInactivityTimer()

                let palmFiltered = touchData.filter { $0.finger != nil && $0.hand != nil }

                if palmFiltered.count != maxTouchesInCurrentGesture,
                   palmFiltered.isEmpty || palmFiltered.count > maxTouchesInCurrentGesture {
                    maxTouchesInCurrentGesture = palmFiltered.count
                }

                if palmFiltered.count == 2, maxTouchesInCurrentGesture == 2 {
                    handleTwoFingerGesture(with: palmFiltered)
                } else {
                    resetGesture()
                }
            }
        }

        subtrack.start()
    }

    func stop() {
        subtrack.stop()
        resetGesture()
    }

    private func resetInactivityTimer() {
        inactivityTask?.cancel()

        inactivityTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return }
            self?.resetGesture()
        }
    }

    private func handleTwoFingerGesture(with touches: [MTContact]) {
        // Skip processing if this gesture sequence was already rejected
        guard !isCurrentGestureRejected else {
            return
        }

        let info = GestureInfo(
            position: averagePosition(of: touches),
            distance: distance(between: touches)
        )

        guard let originInfo = originGestureInfo, let lastInfo = lastGestureInfo else {
            // Check if cursor is over a titlebar before activating
            guard isCursorOverTitlebar() else {
                isCurrentGestureRejected = true // Mark as rejected to skip future events
                return
            }

            let loopWasAlreadyOpen = checkIfLoopOpen()

            originGestureInfo = info
            lastGestureInfo = info
            lastTriggeredActionIndex = nil
            lastTriggeredDistance = 0
            lastTriggeredZoomDistance = info.distance // Initialize to current finger distance
            gestureBlocker.start()

            // Reset position history for new gesture
            positionHistory.removeAll()

            // Only open Loop if it wasn't already open
            if !loopWasAlreadyOpen {
                didOpenLoopWithThisGesture = true
                openCallback(.init(.noSelection))
            }

            return
        }

        // Check for zoom-in gesture first (independent of translation)
        let touch1 = touches[0]
        let touch2 = touches[1]

        let pos1 = CGPoint(
            x: CGFloat(touch1.normalizedVector.position.x),
            y: CGFloat(touch1.normalizedVector.position.y)
        )
        let pos2 = CGPoint(
            x: CGFloat(touch2.normalizedVector.position.x),
            y: CGFloat(touch2.normalizedVector.position.y)
        )

        // Update position history for stable direction detection at low velocities
        positionHistory.append(PositionHistoryEntry(
            avgPosition: info.position,
            touch1Position: pos1,
            touch2Position: pos2,
            timestamp: Date.timeIntervalSinceReferenceDate
        ))
        if positionHistory.count > maxHistoryEntries {
            positionHistory.removeFirst()
        }

        // Calculate zoom distance (finger spread)
        let fingerDistance = info.distance

        // Check if fingers are spreading apart by comparing distances
        let isZooming: Bool
        if let oldFingerDistance = fingerDistanceFromHistory() {
            // Use position history for stable detection
            let distanceChange = fingerDistance - oldFingerDistance
            isZooming = distanceChange > initialGestureThreshold // Use initial threshold for sensitive detection
        } else if positionHistory.count >= 1 {
            // Use last frame's distance if history is building up
            let lastFingerDistance = lastInfo.distance
            let distanceChange = fingerDistance - lastFingerDistance
            isZooming = distanceChange > initialGestureThreshold
        } else {
            // First frame: no zoom detection yet
            isZooming = false
        }

        // Prioritize zoom gestures over directional gestures
        if isZooming {
            let actions = radialMenuActions
            let centerActionIndex = actions.count - 1

            // Trigger center action if it's a new action or moved significantly further
            if let lastIndex = lastTriggeredActionIndex {
                if lastIndex == centerActionIndex {
                    // Same action - only trigger if we've spread fingers further
                    guard fingerDistance >= lastTriggeredDistance + zoomRepeatThreshold else { return }
                }
            }

            lastTriggeredActionIndex = centerActionIndex
            lastTriggeredDistance = fingerDistance
            triggerAction(at: centerActionIndex, from: actions[...])
            return // Don't process directional actions while zooming
        }

        // Process directional actions (swiping)
        let deltaPositionFromLast = CGSize(
            width: info.position.x - lastInfo.position.x,
            height: info.position.y - lastInfo.position.y
        )

        let translationMagFromLast = hypot(deltaPositionFromLast.width, deltaPositionFromLast.height)

        // Use lower threshold for initial gesture when no action is selected
        let threshold: CGFloat = lastTriggeredActionIndex == nil ? initialGestureThreshold : gestureRepeatThreshold
        guard translationMagFromLast >= threshold else { return }

        lastGestureInfo = info

        // Detect backward movement using position history
        let vectorFromOrigin = CGSize(
            width: info.position.x - originInfo.position.x,
            height: info.position.y - originInfo.position.y
        )

        let magFromOrigin = hypot(vectorFromOrigin.width, vectorFromOrigin.height)

        var didReset = false

        // Use position history for stable direction detection
        if let movementDirection = directionFromHistory(to: info.position),
           magFromOrigin > 0 {
            let magMovement = hypot(movementDirection.width, movementDirection.height)

            if magMovement >= initialGestureThreshold { // Only if meaningful movement occurred
                let dotProduct = movementDirection.width * vectorFromOrigin.width +
                    movementDirection.height * vectorFromOrigin.height
                let cosAngle = dotProduct / (magFromOrigin * magMovement)

                // Negative dot product means moving toward origin (opposite direction)
                if cosAngle < -0.5 { // ~120 degree threshold
                    originGestureInfo = info
                    lastTriggeredActionIndex = nil
                    lastTriggeredDistance = 0
                    lastTriggeredZoomDistance = 0
                    didReset = true
                    print("RESET (history)")
                }
            }
        }

        // Clear history after reset so new origin has clean slate
        if didReset {
            positionHistory.removeAll()
        }

        // Calculate angle from origin or movement direction if we just reset
        let angleFromOrigin: CGFloat
        let currentDistance: CGFloat

        if didReset {
            // Use movement direction since we're at the new origin
            angleFromOrigin = atan2(-deltaPositionFromLast.height, deltaPositionFromLast.width) + .pi / 2
            currentDistance = translationMagFromLast
        } else {
            let deltaPositionFromOrigin = CGSize(
                width: info.position.x - originInfo.position.x,
                height: info.position.y - originInfo.position.y
            )
            angleFromOrigin = atan2(-deltaPositionFromOrigin.height, deltaPositionFromOrigin.width) + .pi / 2
            currentDistance = hypot(deltaPositionFromOrigin.width, deltaPositionFromOrigin.height)
        }

        var normalizedAngle = angleFromOrigin
        if normalizedAngle < 0 { normalizedAngle += 2 * .pi }

        let actions = radialMenuActions.dropLast()
        guard actions.count > 1 else { return }

        let newIndex: Int
        if actions.count == 8 {
            // For exactly 8 actions, bias toward cardinal directions
            // Cardinal directions are at indices 0, 2, 4, 6 (N, E, S, W)
            // Diagonal directions are at indices 1, 3, 5, 7 (NE, SE, SW, NW)
            newIndex = indexWithCardinalBias(angle: normalizedAngle, actionCount: actions.count)
        } else {
            // Standard even distribution for other action counts
            let actionAngleSpan = (.pi * 2) / CGFloat(actions.count)
            let halfAngleSpan = actionAngleSpan / 2.0
            newIndex = Int((normalizedAngle + halfAngleSpan) / actionAngleSpan) % actions.count
        }

        // Only trigger if it's a new action OR we've moved significantly further in the same direction
        if let lastIndex = lastTriggeredActionIndex {
            if newIndex == lastIndex {
                // Same action - only trigger if we've moved further from origin
                guard currentDistance >= lastTriggeredDistance + gestureRepeatThreshold else { return }
            }
        }

        lastTriggeredActionIndex = newIndex
        lastTriggeredDistance = currentDistance
        triggerAction(at: newIndex, from: actions)
    }

    func resetGesture() {
        isCurrentGestureRejected = false

        guard lastGestureInfo != nil else {
            return
        }

        // Only close Loop if this gesture was responsible for opening it
        if didOpenLoopWithThisGesture {
            closeCallback(false)
        }

        gestureBlocker.stop()
        lastGestureInfo = nil
        maxTouchesInCurrentGesture = 0
        didOpenLoopWithThisGesture = false
        positionHistory.removeAll() // Clear history on gesture end
    }

    private func averagePosition(of touches: [MTContact]) -> CGPoint {
        let sum = touches.reduce(into: CGPoint.zero) { result, touch in
            result.x += CGFloat(touch.normalizedVector.position.x)
            result.y += CGFloat(touch.normalizedVector.position.y)
        }

        return CGPoint(
            x: sum.x / CGFloat(touches.count),
            y: sum.y / CGFloat(touches.count)
        )
    }

    /// Calculates movement direction from position history
    /// Returns nil if insufficient history available
    private func directionFromHistory(to currentPosition: CGPoint) -> CGSize? {
        guard positionHistory.count >= 3 else { return nil }

        // Use oldest available position for maximum stability
        let oldestEntry = positionHistory.first!

        return CGSize(
            width: currentPosition.x - oldestEntry.avgPosition.x,
            height: currentPosition.y - oldestEntry.avgPosition.y
        )
    }

    /// Calculates finger spread from position history
    /// Returns nil if insufficient history available
    private func fingerDistanceFromHistory() -> CGFloat? {
        guard let oldestEntry = positionHistory.first else { return nil }

        let oldDistance = hypot(
            oldestEntry.touch2Position.x - oldestEntry.touch1Position.x,
            oldestEntry.touch2Position.y - oldestEntry.touch1Position.y
        )

        return oldDistance
    }

    private func distance(between touches: [MTContact]) -> CGFloat {
        guard touches.count == 2 else { return 0 }

        let p1 = CGPoint(x: CGFloat(touches[0].normalizedVector.position.x), y: CGFloat(touches[0].normalizedVector.position.y))
        let p2 = CGPoint(x: CGFloat(touches[1].normalizedVector.position.x), y: CGFloat(touches[1].normalizedVector.position.y))

        return hypot(p2.x - p1.x, p2.y - p1.y)
    }

    /// Maps an angle to an action index with bias toward cardinal directions.
    /// For 8 actions, cardinal directions (N, E, S, W) get wider angular ranges,
    /// requiring users to explicitly aim for ~45° to trigger diagonal actions.
    /// - Parameter cardinalBias: How much larger cardinals are relative to diagonals.
    ///   A value of 0.1 makes cardinal zones 10% wider and diagonal zones 10% narrower than uniform (0.0 = equal sizes, 1.0 = diagonals disappear).
    private func indexWithCardinalBias(angle: CGFloat, actionCount: Int, cardinalBias: CGFloat = 0.1) -> Int {
        let baseAngleSpan = (.pi * 2) / CGFloat(actionCount) // 45° for 8 actions
        let halfAngleSpan = baseAngleSpan / 2.0

        // Match the original centered mapping (boundaries at ±22.5° for 8 actions)
        let adjustedAngle = (angle + halfAngleSpan).truncatingRemainder(dividingBy: .pi * 2)

        // Determine which 45° segment we're in (modulo handles angle == 2π)
        let rawSegment = Int(adjustedAngle / baseAngleSpan) % actionCount

        // Calculate position within the segment (0.0 to 1.0)
        let segmentAngle = adjustedAngle.truncatingRemainder(dividingBy: baseAngleSpan)
        let normalizedPosition = segmentAngle / baseAngleSpan

        // Cardinal directions are at even indices (0, 2, 4, 6)
        let isCurrentCardinal = rawSegment % 2 == 0

        if isCurrentCardinal {
            // Cardinal keeps its entire segment
            return rawSegment
        } else {
            // Diagonal segment - cede edges to adjacent cardinals
            if normalizedPosition < cardinalBias / 2 {
                return (rawSegment - 1 + actionCount) % actionCount
            } else if normalizedPosition > 1.0 - cardinalBias / 2 {
                return (rawSegment + 1) % actionCount
            } else {
                return rawSegment
            }
        }
    }

    private func isCursorOverTitlebar() -> Bool {
        // If Loop is already open, intercept all gestures regardless of cursor position
        if checkIfLoopOpen() {
            return true
        }

        // Get current cursor position
        let cursorPosition = NSEvent.mouseLocation.flipY(screen: NSScreen.screens[0])

        // Get window at cursor position using existing WindowUtility
        guard let window = WindowUtility.windowAtPosition(cursorPosition) else {
            return false
        }

        // Respect app exclusion settings
        if window.isAppExcluded {
            return false
        }

        // Assume large titlebar variant
        let titlebarHeight: CGFloat = 52.0

        let titlebarMinY = window.frame.minY
        let titlebarMaxY = window.frame.minY + titlebarHeight

        let isInTitlebar = cursorPosition.y >= titlebarMinY && cursorPosition.y <= titlebarMaxY

        // Check if cursor is within titlebar region
        return isInTitlebar
    }

    private func triggerAction(at index: Int, from actions: ArraySlice<RadialMenuAction>) {
        let action = actions[index]

        let resolvedAction: WindowAction = switch action.type {
        case let .custom(windowAction):
            windowAction
        case let .keybindReference(id):
            windowActionCache.actionsByIdentifier[id] ?? Self.failedToResolveKeybindAction
        }

        changeAction(resolvedAction)
    }

    private func triggerCenterAction() {
        // The center action is the last item in radialMenuActions
        guard let centerAction = radialMenuActions.last else { return }

        let resolvedAction: WindowAction = switch centerAction.type {
        case let .custom(windowAction):
            windowAction
        case let .keybindReference(id):
            windowActionCache.actionsByIdentifier[id] ?? Self.failedToResolveKeybindAction
        }

        changeAction(resolvedAction)
    }
}

@Loggable
private final class GestureBlocker {
    private var monitor: ActiveEventMonitor?

    func start() {
        log.info("Starting gesture blocker")

        let eventTypes: [CGEventType] = [
            .scrollWheel,
            CGEventType(rawValue: UInt32(NSEvent.EventType.gesture.rawValue)),
            CGEventType(rawValue: UInt32(NSEvent.EventType.magnify.rawValue)),
            CGEventType(rawValue: UInt32(NSEvent.EventType.rotate.rawValue)),
            CGEventType(rawValue: UInt32(NSEvent.EventType.smartMagnify.rawValue))
        ].compactMap(\.self)

        monitor = ActiveEventMonitor(events: eventTypes) { _ in .ignore }
        monitor?.start()
    }

    func stop() {
        monitor?.stop()
        monitor = nil

        log.info("Stopped gesture blocker")
    }
}
