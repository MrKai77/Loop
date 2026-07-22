//
//  KeybindTrigger.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-18.
//

import Cocoa
import Defaults
import os
import Scribe

/// Monitors keyboard input and invokes Loop's open and close callbacks for configured actions.
///
/// The active event monitor remains the primary input path because it supports Loop's full chord
/// model and radial-menu lifecycle. A narrow Carbon hotkey path mirrors compatible shortcuts so
/// they still work while Secure Input prevents macOS from delivering ordinary keys to event taps.
@Loggable
final class KeybindTrigger {
    // Parameters
    private let windowActionCache: WindowActionCache

    /// Owns the Carbon registrations used only for Secure Input-compatible fallback shortcuts.
    private let systemHotKeyMonitor: SystemHotKeyMonitor

    /// Moves Carbon callbacks onto the event-tap thread where existing keybind state is mutated.
    /// Injectable scheduling lets tests hold a callback long enough to verify stale-work rejection.
    private let systemHotKeyScheduler: (@escaping () -> Void) -> Void
    private let openCallback: (WindowAction) -> ()
    private let closeCallback: (Bool) -> ()
    private let checkIfLoopOpen: () -> Bool

    // State-tracking
    private var pressedKeys: Set<CGKeyCode> = []
    private(set) var effectiveEventFlags: CGEventFlags = []
    private var eventMonitor: ActiveEventMonitor?

    /// Rebuilds Carbon registrations whenever a setting that shapes a shortcut changes.
    private var systemHotKeyDefaultsObservationTask: Task<Void, Never>?

    /// Tracks presses across the main-thread Carbon callback and event-tap-thread action handler.
    /// It prevents duplicate non-repeatable presses while retaining Carbon key-repeat behavior.
    private let activeSystemHotKeyPresses: OSAllocatedUnfairLock<Set<SystemHotKeyShortcut>> = .init(
        initialState: []
    )

    /// Invalidates callbacks queued before a settings rebuild or `stop`.
    private let systemHotKeyGeneration: OSAllocatedUnfairLock<UInt64> = .init(initialState: 0)

    private var systemKeybindCache: Set<Set<CGKeyCode>> = []
    private var keybindCacheUpdatedAt: ContinuousClock.Instant?
    private let keybindCacheLifetime: ContinuousClock.Duration = .seconds(30)

    /// Special events only contain the globe key, as it can also be used as an emoji key.
    private let specialEventKeys: [CGKeyCode] = [.kVK_Globe_Emoji]

    /// Will be set to `false` if the mouse has been moved by LoopManager.
    var canPassthroughNextSpecialEvent = true

    private var useTriggerDelay: Bool { Defaults[.triggerDelay] > 0.1 }
    private var doubleClickToTrigger: Bool { Defaults[.doubleClickToTrigger] }
    private var sideDependentTriggerKey: Bool { Defaults[.sideDependentTriggerKey] }
    private var triggerKey: Set<CGKeyCode> {
        sideDependentTriggerKey ? Defaults[.triggerKey] : Defaults[.triggerKey].baseModifiers
    }

    private lazy var triggerDelayTimer = TriggerDelayTimer(openCallback: openCallback)
    private lazy var doubleClickTimer = DoubleClickTimer { [weak self] action in
        guard let self else { return }

        if useTriggerDelay {
            startTriggerDelayTimer(
                startingAction: action,
                overrideExistingTriggerDelayTimerAction: true
            )
        } else {
            openCallback(action)
        }
    }

    /// Schedules fallback input on the same run loop as normal event-tap input.
    ///
    /// Keeping both sources on one thread preserves the ordering assumptions in `pressedKeys`,
    /// trigger-delay handling, and the open/close callbacks.
    private static func scheduleOnEventTapThread(_ operation: @escaping () -> Void) -> Void {
        let runLoop: CFRunLoop = EventTapThread.shared.runLoop
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
            operation()
        }
        CFRunLoopWakeUp(runLoop)
    }

    /// Initializes a keyboard trigger with event-tap input and the compatible Carbon fallback.
    /// - Parameters:
    ///   - windowActionCache: resolves normal and trigger-bypassing key sets to Loop actions.
    ///   - systemHotKeyMonitor: owns Carbon registrations; injectable for deterministic tests.
    ///   - systemHotKeyScheduler: transfers Carbon callbacks to the event-tap thread.
    ///   - openCallback: what to do when the trigger key is pressed, and Loop should be activated.
    ///   - closeCallback: what to do when the trigger key is released, and Loop should be closed.
    ///   - checkIfLoopOpen: returns the current Loop presentation state.
    init(
        windowActionCache: WindowActionCache,
        systemHotKeyMonitor: SystemHotKeyMonitor = .init(),
        systemHotKeyScheduler: @escaping (@escaping () -> Void) -> Void = KeybindTrigger.scheduleOnEventTapThread,
        openCallback: @escaping (WindowAction) -> (),
        closeCallback: @escaping (Bool) -> (),
        checkIfLoopOpen: @escaping () -> Bool
    ) {
        self.windowActionCache = windowActionCache
        self.systemHotKeyMonitor = systemHotKeyMonitor
        self.systemHotKeyScheduler = systemHotKeyScheduler
        self.openCallback = openCallback
        self.closeCallback = closeCallback
        self.checkIfLoopOpen = checkIfLoopOpen
        systemHotKeyMonitor.eventCallback = { [weak self] binding, phase in
            self?.scheduleSystemHotKey(binding: binding, phase: phase)
        }
    }

    func start() async {
        guard await AccessibilityManager.shared.isGranted else {
            return
        }

        await MainActor.run {
            // A Carbon registration encodes the complete chord, so every setting that changes the
            // chord's shape requires the registrations to be rebuilt.
            let updates: AsyncStream<(Set<CGKeyCode>, Bool, [WindowAction], Bool)> = Defaults.updates(
                .triggerKey,
                .sideDependentTriggerKey,
                .keybinds,
                .cycleBackwardsOnShiftPressed,
                initial: false
            )
            rebuildSystemHotKeys()
            systemHotKeyDefaultsObservationTask?.cancel()
            systemHotKeyDefaultsObservationTask = Task { @MainActor [weak self] in
                for await _ in updates {
                    guard !Task.isCancelled, let self else { break }
                    rebuildSystemHotKeys()
                }
            }
        }

        eventMonitor?.stop()

        let eventMonitor = ActiveEventMonitor(
            "keybind_trigger",
            events: [.keyDown, .keyUp, .flagsChanged]
        ) { [weak self] event -> ActiveEventMonitor.EventHandling in
            guard let self else { return .forward }

            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                .baseKey(flags: .init(rawValue: UInt(event.flags.rawValue)))

            var filteredFlags = event.flags
            if keyCode.isFnSpecialKey, !effectiveEventFlags.contains(.maskSecondaryFn) {
                filteredFlags.remove(.maskSecondaryFn)
            }

            let isLoopOpen = checkIfLoopOpen()
            effectiveEventFlags = filteredFlags

            if event.type == .keyUp {
                pressedKeys.remove(keyCode)
            } else if event.type == .keyDown {
                pressedKeys.insert(keyCode)
            }

            // Special events such as the emoji key
            if specialEventKeys.contains(keyCode) {
                let canPassthrough = canPassthroughNextSpecialEvent
                canPassthroughNextSpecialEvent = true // reset
                return canPassthrough ? .forward : .ignore
            }

            let pressedKeyCodes: Set<CGKeyCode> = pressedKeys
                .union(filteredFlags.keyCodes)
                .baseModifiers

            // Carbon and the event tap both see registered shortcuts when Secure Input is off.
            // Forward the event-tap copy so one physical key press performs exactly one action.
            if shouldDeferToSystemHotKey(type: event.type, keyCodes: pressedKeyCodes) {
                return .forward
            }

            // If this is a valid event, don't passthrough
            let result = performKeybind(
                type: event.type,
                isARepeat: event.getIntegerValueField(.keyboardEventAutorepeat) == 1,
                flags: filteredFlags,
                isLoopOpen: isLoopOpen
            )

            if result == .consume {
                log.debug("Blocked event")
                return .ignore
            }

            // If this shouldn't consume the event, and Loop isn't in the process of opening (possibly due to trigger delays),
            // check if it was a system keybind (ex. screenshot), and in that case, passthrough and force-close Loop
            refreshSystemKeybindCacheIfNeeded()
            if result != .opening, event.type == .keyDown, systemKeybindCache.contains(pressedKeys) {
                closeLoop(forceClose: true)
            }

            return .forward
        }

        eventMonitor.start()
        self.eventMonitor = eventMonitor
    }

    func stop() {
        precondition(Thread.isMainThread)

        // Invalidate queued work before tearing down registrations so no late Carbon callback can
        // reopen Loop after this trigger has stopped.
        invalidateSystemHotKeyEvents()
        systemHotKeyDefaultsObservationTask?.cancel()
        systemHotKeyDefaultsObservationTask = nil
        systemHotKeyMonitor.stop()
        activeSystemHotKeyPresses.withLock { $0.removeAll() }
        eventMonitor?.stop()
        eventMonitor = nil

        // Reset states
        pressedKeys = []
        canPassthroughNextSpecialEvent = true
    }

    /// Replaces Carbon registrations with the currently configured compatible shortcut subset.
    ///
    /// Active presses are cleared because releases from the old registration set must not affect
    /// actions registered after the settings change.
    func rebuildSystemHotKeys() -> Void {
        precondition(Thread.isMainThread)
        invalidateSystemHotKeyEvents()
        activeSystemHotKeyPresses.withLock { $0.removeAll() }

        let bindings: [SystemHotKeyBinding] = SystemHotKeyBindingResolver.resolve(
            keybinds: Defaults[.keybinds],
            triggerKey: Defaults[.triggerKey],
            sideDependentTriggerKey: Defaults[.sideDependentTriggerKey],
            cycleBackwardsOnShiftPressed: Defaults[.cycleBackwardsOnShiftPressed]
        )
        systemHotKeyMonitor.rebuild(bindings: bindings)
    }

    /// Returns whether a key-down event has already been claimed by a Carbon registration.
    ///
    /// Only key-down is deferred. The existing event-tap release and modifier processing remains
    /// available for Loop's normal trigger-key lifecycle.
    func shouldDeferToSystemHotKey(type: CGEventType, keyCodes: Set<CGKeyCode>) -> Bool {
        guard type == .keyDown, let shortcut: SystemHotKeyShortcut = .init(keyCodes: keyCodes) else {
            return false
        }
        return systemHotKeyMonitor.isRegistered(shortcut: shortcut)
    }

    /// Advances the generation captured by scheduled callbacks, making all older work inert.
    private func invalidateSystemHotKeyEvents() -> Void {
        systemHotKeyGeneration.withLock { $0 &+= 1 }
    }

    /// Captures main-thread Carbon state before handing the event to `EventTapThread`.
    private func scheduleSystemHotKey(binding: SystemHotKeyBinding, phase: SystemHotKeyPhase) -> Void {
        precondition(Thread.isMainThread)
        let generation: UInt64 = systemHotKeyGeneration.withLock { $0 }

        // Carbon supplies the registered key and generic modifiers, but not a `CGEvent`. Capture
        // current flags here so downstream action selection sees the same session state it would
        // have received from the event tap.
        let eventFlags: CGEventFlags = CGEventSource.flagsState(.combinedSessionState)

        systemHotKeyScheduler { [weak self] in
            // Rebuild and stop both advance the generation before queued work can run.
            guard let self, systemHotKeyGeneration.withLock({ $0 }) == generation else { return }
            handleSystemHotKey(binding: binding, phase: phase, eventFlags: eventFlags)
        }
    }

    /// Applies Carbon press/release semantics through the existing Loop action lifecycle.
    private func handleSystemHotKey(
        binding: SystemHotKeyBinding,
        phase: SystemHotKeyPhase,
        eventFlags: CGEventFlags
    ) -> Void {
        switch phase {
        case .pressed:
            effectiveEventFlags = eventFlags

            // Carbon may emit repeated press events while a key is held. Match the event-tap path
            // by accepting those only for actions whose direction explicitly supports repetition.
            let shouldOpen: Bool = activeSystemHotKeyPresses.withLock { shortcuts in
                shortcuts.insert(binding.shortcut).inserted || binding.action.canRepeat
            }
            guard shouldOpen else { return }
            openLoop(
                startingAction: binding.action,
                overrideExistingTriggerDelayTimerAction: true
            )

        case .released:
            // Ignore unmatched releases, including releases from a registration invalidated by a
            // rebuild. Only bypass actions own their full lifecycle; normal actions still follow
            // the trigger key managed by the event-tap path.
            let wasActive: Bool = activeSystemHotKeyPresses.withLock { shortcuts in
                shortcuts.remove(binding.shortcut) != nil
            }
            guard wasActive, binding.bypassesTrigger else { return }
            closeLoopPreservingEventTapPressedKeys(forceClose: false)
        }
    }

    enum PerformKeybindResult {
        case consume
        case forward
        case opening
    }

    /// Determines if an event corresponds to a valid Loop action.
    /// - Parameters:
    ///   - type: the type of this event.
    ///   - isARepeat: whether this event is a repeat event.
    ///   - flags: modifier flags associated with this event.
    ///   - isLoopOpen: whether Loop is currently open.
    /// - Returns: whether this event was processed by Loop.
    private func performKeybind(type: CGEventType, isARepeat: Bool, flags: CGEventFlags, isLoopOpen: Bool) -> PerformKeybindResult {
        let flagKeys = sideDependentTriggerKey ? flags.keyCodes : flags.keyCodes.baseModifiers
        let allPressedKeys: Set<CGKeyCode> = pressedKeys.union(flagKeys)

        let containsTrigger = allPressedKeys.isSuperset(of: triggerKey)
        let actionKeys: Set<CGKeyCode> = Set(allPressedKeys.subtracting(triggerKey).map(\.baseModifier))
        let allPressedKeysBaseModifiers: Set<CGKeyCode> = Set(allPressedKeys.map(\.baseModifier))

        if isLoopOpen {
            if pressedKeys.contains(.kVK_Escape) {
                closeLoop(forceClose: true)
                return .consume
            }

            if type == .keyUp {
                return .forward
            }

            if type != .keyDown, !containsTrigger {
                closeLoop(forceClose: false)
                return .forward
            }
        }

        if type != .keyUp { // keyDown for flagsChanged
            if containsTrigger {
                // Try an match directly with the action keys first, then fallback to just the key code.
                // This prevents failures when the user is tapping the keys in rapid succession.
                if let action = windowActionCache.actionsByKeybind[actionKeys] {
                    if !isARepeat || action.canRepeat {
                        openLoop(startingAction: action, overrideExistingTriggerDelayTimerAction: true)
                    }

                    // Only consume the event if the last command actually opened Loop.
                    // The main reason Loop *wouldn't* open after an `openLoop` call would be because the user has enabled a trigger delay.
                    return checkIfLoopOpen() ? .consume : .opening
                }

                // Only trigger Loop without an action if the only pressed keys perfectly matches the trigger key.
                if allPressedKeys == triggerKey {
                    openLoop(
                        startingAction: .init(.noSelection),
                        overrideExistingTriggerDelayTimerAction: !isARepeat
                    )
                    return .opening
                }
            } else if let bypassedAction = windowActionCache.bypassedActionsByKeybind[allPressedKeysBaseModifiers] {
                if !isARepeat || bypassedAction.canRepeat {
                    openLoop(startingAction: bypassedAction, overrideExistingTriggerDelayTimerAction: true)
                }

                return checkIfLoopOpen() ? .consume : .opening
            } else {
                if allPressedKeys.isEmpty {
                    doubleClickTimer.handleKeyUp()
                }
                closeLoop(forceClose: false)
            }
        }

        // If this wasn't a valid keybind, return false, which will then forward the key event to the frontmost app
        return .forward
    }

    private func openLoop(startingAction: WindowAction, overrideExistingTriggerDelayTimerAction: Bool) {
        if checkIfLoopOpen() {
            openCallback(startingAction) // Only update Loop to the latest WindowAction
        } else {
            if doubleClickToTrigger {
                doubleClickTimer.handleKeyDown(startingAction: startingAction)
            } else if useTriggerDelay {
                startTriggerDelayTimer(
                    startingAction: startingAction,
                    overrideExistingTriggerDelayTimerAction: overrideExistingTriggerDelayTimerAction
                )
            } else {
                openCallback(startingAction)
            }
        }
    }

    private func closeLoop(forceClose: Bool) {
        closeLoopPreservingEventTapPressedKeys(forceClose: forceClose)
        pressedKeys = []
    }

    /// Closes a Carbon bypass action without erasing keys owned by the event-tap input stream.
    ///
    /// Clearing `pressedKeys` here would lose unrelated physical keys that remain held and corrupt
    /// the next event-tap chord. Existing event-tap callers use `closeLoop`, which still resets it.
    private func closeLoopPreservingEventTapPressedKeys(forceClose: Bool) {
        triggerDelayTimer.cancel()
        closeCallback(forceClose)
    }

    private func startTriggerDelayTimer(
        startingAction: WindowAction,
        overrideExistingTriggerDelayTimerAction: Bool
    ) {
        // If a trigger delay timer is already active, only update its startingAction when
        // overrideExistingTriggerDelayTimerAction is true. If it's false, keep the existing
        // timer and its startingAction (do not create a new timer with nil).
        if triggerDelayTimer.isActive {
            if overrideExistingTriggerDelayTimerAction {
                triggerDelayTimer.updateStartingAction(with: startingAction)
            }
        } else {
            // No active timer, create one with the provided startingAction.
            triggerDelayTimer.handleTrigger(startingAction: startingAction)
        }
    }

    private func refreshSystemKeybindCacheIfNeeded() {
        let shouldRefresh: Bool = if let keybindCacheUpdatedAt {
            keybindCacheUpdatedAt.duration(to: .now) > keybindCacheLifetime
        } else {
            true
        }

        guard shouldRefresh else {
            return
        }

        systemKeybindCache = CGKeyCode.systemKeybinds
        keybindCacheUpdatedAt = .now
    }
}
