//
//  MultitouchRecognizerRegistry.swift
//  Loop
//
//  Created by Kai Azim on 2026-07-06.
//

import Subsurface

@MainActor
final class MultitouchRecognizerRegistry {
    typealias EventHandler = @MainActor (SubsurfaceGestureEvent, Int) async -> ()

    struct Entry {
        let recognizer: SubsurfaceGestureRecognizer
        let session: MultitouchGestureSession
        var task: Task<(), Never>?
        var radialMenuGesture: GestureBinding?
        var directionalGestures: [GestureBinding]
        var pinchGesture: GestureBinding?
        var spreadGesture: GestureBinding?

        static func categorize(
            _ gestures: [GestureBinding]
        ) -> (radial: GestureBinding?, directionals: [GestureBinding], pinch: GestureBinding?, spread: GestureBinding?) {
            let radial = gestures.first { $0.kind == .radialMenu }
            let directionals = gestures.filter(\.kind.isDirectionalPan)
            let pinch = gestures.first { $0.kind == .pinch }
            let spread = gestures.first { $0.kind == .spread }
            return (radial, directionals, pinch, spread)
        }
    }

    struct StopResult {
        let didOpenLoopWithGesture: Bool
    }

    private let gestureMonitor: SubsurfaceMonitor
    private let handleEvent: EventHandler
    private var entries: [Int: Entry] = [:]

    init(
        gestureMonitor: SubsurfaceMonitor,
        handleEvent: @escaping EventHandler
    ) {
        self.gestureMonitor = gestureMonitor
        self.handleEvent = handleEvent
    }

    func entry(for fingerCount: Int) -> Entry? {
        entries[fingerCount]
    }

    func session(for fingerCount: Int) -> MultitouchGestureSession? {
        entries[fingerCount]?.session
    }

    func rebuild(with gestures: [GestureBinding]) -> [StopResult] {
        let conflictingIDs = GestureBinding.conflictingActionableIDs(in: gestures)
        let activeGestures = gestures.filter { !conflictingIDs.contains($0.id) }
        let gesturesByFingerCount = Dictionary(grouping: activeGestures, by: \.fingerCount)
        let neededFingerCounts = Set(gesturesByFingerCount.keys)

        var stopResults: [StopResult] = []
        for fingerCount in Array(entries.keys) where !neededFingerCounts.contains(fingerCount) {
            if let stopResult = stopRecognizer(for: fingerCount) {
                stopResults.append(stopResult)
            }
            entries.removeValue(forKey: fingerCount)
        }

        for (fingerCount, gestures) in gesturesByFingerCount {
            let (radial, directionals, pinch, spread) = Entry.categorize(gestures)
            if entries[fingerCount] == nil {
                startRecognizer(for: fingerCount, radial: radial, directionals: directionals, pinch: pinch, spread: spread)
            } else {
                entries[fingerCount]?.radialMenuGesture = radial
                entries[fingerCount]?.directionalGestures = directionals
                entries[fingerCount]?.pinchGesture = pinch
                entries[fingerCount]?.spreadGesture = spread
            }
        }

        return stopResults
    }

    func stopAll() -> [StopResult] {
        var stopResults: [StopResult] = []
        for fingerCount in Array(entries.keys) {
            if let stopResult = stopRecognizer(for: fingerCount) {
                stopResults.append(stopResult)
            }
        }
        entries.removeAll()
        return stopResults
    }

    func contains(session: MultitouchGestureSession, for fingerCount: Int) -> Bool {
        entries[fingerCount]?.session === session
    }

    private func startRecognizer(
        for fingerCount: Int,
        radial: GestureBinding?,
        directionals: [GestureBinding],
        pinch: GestureBinding?,
        spread: GestureBinding?
    ) {
        let recognizer = SubsurfaceGestureRecognizer(
            fingerCount: fingerCount,
            requiresExactFingerCountToContinue: true
        )

        entries[fingerCount] = Entry(
            recognizer: recognizer,
            session: MultitouchGestureSession(),
            task: nil,
            radialMenuGesture: radial,
            directionalGestures: directionals,
            pinchGesture: pinch,
            spreadGesture: spread
        )

        let task = Task { [weak self] in
            guard let self else { return }
            for await event in recognizer.events(from: gestureMonitor) {
                guard !Task.isCancelled else { break }
                await handleEvent(event, fingerCount)
            }
        }
        entries[fingerCount]?.task = task
    }

    private func stopRecognizer(for fingerCount: Int) -> StopResult? {
        guard let entry = entries[fingerCount] else { return nil }
        entry.task?.cancel()
        entry.recognizer.reset()
        return StopResult(didOpenLoopWithGesture: entry.session.didOpenLoopWithThisGesture)
    }
}
