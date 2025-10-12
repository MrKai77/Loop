//
//  KeybindMonitor.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-18.
//

import Cocoa
import Defaults

final class KeybindMonitor {
    private var eventMonitor: ActiveEventMonitor?

    private var pressedKeys: Set<CGKeyCode> = []
    private var lastKeyReleaseTime: Date = .now

    // Currently, special events only contain the globe key, as it can also be used as a emoji key.
    private let specialEvents: [CGKeyCode] = [179]
    var canPassthroughSpecialEvents = true // If mouse has been moved

    func start() {
        guard eventMonitor == nil, AccessibilityManager.getStatus() else {
            return
        }

        eventMonitor = ActiveEventMonitor(events: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            guard let self else { return .forward }
            print("EVENT")

            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

            if !keyCode.isModifier {
                if event.type == .keyUp {
                    pressedKeys.remove(keyCode.baseKey)
                } else if event.type == .keyDown {
                    pressedKeys.insert(keyCode.baseKey)
                }
            }

            // Special events such as the emoji key
//            if specialEvents.contains(keyCode.baseKey) {
//                return canPassthroughSpecialEvents ? .forward : .ignore
//            }

            // If this is a valid event, don't passthrough
            if performKeybind(event: event) {
                return .ignore
            }

            // If this wasn't, check if it was a system keybind (ex. screenshot), and
            // in that case, passthrough and force-close Loop
//            if CGKeyCode.systemKeybinds.contains(pressedKeys) {
//                LoopManager.shared.forceCloseLoop()
//                return .forward
//            }

            return .forward
        }

        eventMonitor!.start()
    }

    func stop() {
        pressedKeys = []
        canPassthroughSpecialEvents = true

        eventMonitor?.stop()
        eventMonitor = nil
    }

    private func performKeybind(event: CGEvent) -> Bool {
        let isRepeatEvent = event.getIntegerValueField(.keyboardEventAutorepeat) == 1
        let triggerKey: Set<CGKeyCode> = Defaults[.triggerKey]

        let pressedKeys: Set<CGKeyCode> = pressedKeys.union(event.flags.keyCodes)
        let actionKeys: Set<CGKeyCode> = pressedKeys.subtracting(triggerKey)
        let containsTrigger = pressedKeys.isSuperset(of: triggerKey)

        if LoopManager.shared.isLoopActive {
            if pressedKeys.contains(.kVK_Escape) {
                self.pressedKeys = []
                canPassthroughSpecialEvents = true

                LoopManager.shared.closeLoop(forceClose: true)
                return true
            }

            if event.type == .keyUp {
                // Ignore key-up events occurring within 100ms of each other.
                // Prevents direction changes when rapidly (normally) releasing multiple pressed keys.
                if abs(lastKeyReleaseTime.timeIntervalSinceNow) > 0.1 {
                    lastKeyReleaseTime = Date.now
                }

                return true
            }

            if event.type != .keyDown, !containsTrigger {
                LoopManager.shared.closeLoop(forceClose: false)
                return true
            }
        }

        if event.type != .keyUp, containsTrigger {
            if let action = WindowActionCache.shared[actionKeys], !isRepeatEvent || action.willManipulateExistingWindowFrame {
                LoopManager.shared.openLoop(startingAction: action)
            } else {
                LoopManager.shared.openLoop(startingAction: nil)
            }

            return true
        }

        // If this wasn't a valid keybind, return false, which will then forward the key event to the frontmost app
        return false
    }
}
