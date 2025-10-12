//
//  KeybindObserver.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-18.
//

import Cocoa
import Defaults

final class KeybindObserver {
    // Callbacks
    private let openCallback: (WindowAction?) -> ()
    private let closeCallback: (Bool) -> ()
    private let checkIfLoopOpen: () -> Bool

    // State-tracking
    private var pressedKeys: Set<CGKeyCode> = []
    private var lastKeyReleaseTime: Date = .now
    private var eventMonitor: ActiveEventMonitor?

    // Special events only contain the globe key, as it can also be used as an emoji key.
    private let specialEvents: [CGKeyCode] = [.kVK_Globe_Emoji]
    var canPassthroughSpecialEvents = true // If mouse has been moved

    /// Initializes a ``KeybindObserver``.
    /// - Parameters:
    ///   - openCallback: what to do when the trigger key is pressed, and Loop should be activated.
    ///   - closeCallback: what to do when the trigger key is released, and Loop should be closed.
    init(
        openCallback: @escaping (WindowAction?) -> (),
        closeCallback: @escaping (Bool) -> (),
        checkIfLoopOpen: @escaping () -> Bool
    ) {
        // We will never start off with an action from this trigger, so pass in nil
        self.openCallback = openCallback
        self.closeCallback = closeCallback
        self.checkIfLoopOpen = checkIfLoopOpen
    }

    func start() {
        guard eventMonitor == nil, AccessibilityManager.shared.isGranted else {
            return
        }

        eventMonitor = ActiveEventMonitor(events: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event -> ActiveEventMonitor.EventHandling in
            guard let self else { return .forward }

            /// When Command + arrow keys are pressed simultaneously, we've observed that the CGEvent
            /// incorrectly has the function key flag along with `CGEventFlags(rawValue: 1 << 21)` added to the modifier flags.
            /// This is inconsistent behavior as function keys should only be set when actual function keys are pressed.
            /// The following code detects this specific scenario and removes the set function flag.
            var flags = event.flags
            let commandArrowKeyFlag = CGEventFlags(rawValue: 1 << 21)
            if flags.contains(commandArrowKeyFlag) {
                flags.remove(.maskFunction)
            }

            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)).baseKey(flags: .init(rawValue: UInt(flags.rawValue)))

            if event.type == .keyUp {
                pressedKeys.remove(keyCode)
            } else if event.type == .keyDown {
                pressedKeys.insert(keyCode)
            }

            // Special events such as the emoji key
            if specialEvents.contains(keyCode) {
                return canPassthroughSpecialEvents ? .forward : .ignore
            }

            // If this is a valid event, don't passthrough
            if performKeybind(
                type: event.type,
                isARepeat: event.getIntegerValueField(.keyboardEventAutorepeat) == 1,
                flags: flags
            ) {
                return .ignore
            }

            // If this wasn't, check if it was a system keybind (ex. screenshot), and
            // in that case, passthrough and force-close Loop
            if CGKeyCode.systemKeybinds.contains(pressedKeys) {
                closeCallback(true)
                return .forward
            }

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

    private func performKeybind(type: CGEventType, isARepeat: Bool, flags: CGEventFlags) -> Bool {
        let triggerKey: Set<CGKeyCode> = Defaults[.triggerKey]

        let pressedKeys: Set<CGKeyCode> = pressedKeys.union(flags.keyCodes)
        let actionKeys: Set<CGKeyCode> = pressedKeys.subtracting(triggerKey)
        let containsTrigger = pressedKeys.isSuperset(of: triggerKey)

        if checkIfLoopOpen() {
            if pressedKeys.contains(.kVK_Escape) {
                self.pressedKeys = []
                canPassthroughSpecialEvents = true

                closeCallback(true)
                return true
            }

            if type == .keyUp {
                // Ignore key-up events occurring within 100ms of each other.
                // Prevents direction changes when rapidly (normally) releasing multiple pressed keys.
                if abs(lastKeyReleaseTime.timeIntervalSinceNow) > 0.1 {
                    lastKeyReleaseTime = Date.now
                }

                return true
            }

            if type != .keyDown, !containsTrigger {
                closeCallback(false)
                return true
            }
        }

        if type != .keyUp, containsTrigger {
            if let action = WindowActionCache.shared[actionKeys], !isARepeat || action.willManipulateExistingWindowFrame {
                openCallback(action)
            } else {
                openCallback(nil)
            }

            return true
        }

        // If this wasn't a valid keybind, return false, which will then forward the key event to the frontmost app
        return false
    }
}
