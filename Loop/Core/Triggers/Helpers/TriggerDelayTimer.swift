//
//  TriggerDelayTimer.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-27.
//

import Defaults
import Foundation

final class TriggerDelayTimer {
    private var triggerDelayTimer: Task<(), Never>?
    private var startingAction: WindowAction?
    private let openCallback: (WindowAction?) -> ()
    private var triggerDelay: CGFloat { Defaults[.triggerDelay] }

    var isActive: Bool {
        triggerDelayTimer != nil
    }

    init(openCallback: @escaping (WindowAction?) -> ()) {
        self.openCallback = openCallback
    }

    func handleTrigger(startingAction: WindowAction?) {
        self.startingAction = startingAction
        cancel() // Ensure no previous timer is active
        triggerDelayTimer = Task { @MainActor in
            try? await Task.sleep(for: .seconds(triggerDelay))
            guard !Task.isCancelled else { return }

            openCallback(self.startingAction)
            cancel()
        }
    }

    deinit {
        cancel()
    }

    func updateStartingAction(with newAction: WindowAction?) {
        startingAction = newAction
    }

    func cancel() {
        triggerDelayTimer?.cancel()
        triggerDelayTimer = nil
        startingAction = nil
    }
}
