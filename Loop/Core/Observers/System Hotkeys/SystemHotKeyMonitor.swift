import Carbon.HIToolbox
import os
import Scribe

/// The two lifecycle events emitted by Carbon for a registered global hotkey.
enum SystemHotKeyPhase: Equatable {
    case pressed
    case released
}

/// Carbon reports only a numeric registration ID, which the monitor later maps back to a binding.
struct SystemHotKeyEvent: Equatable {
    let id: UInt32
    let phase: SystemHotKeyPhase
}

/// Isolates the Carbon registration API from binding lifecycle and makes failure paths testable.
///
/// All lifecycle methods are called on the main thread because Carbon's application event target
/// belongs to the main event loop. Implementations report raw `OSStatus` values so the monitor can
/// log failures while retaining the event-tap fallback for registrations that did not succeed.
protocol SystemHotKeyRegistrationBackend: AnyObject {
    var eventCallback: ((SystemHotKeyEvent) -> Void)? { get set }

    func start() -> OSStatus
    func register(shortcut: SystemHotKeyShortcut, id: UInt32) -> OSStatus
    func unregisterAll() -> Bool
    func stop() -> Bool
}

/// Owns Carbon's event handler and the `EventHotKeyRef` values needed to unregister every shortcut.
@Loggable
private final class CarbonSystemHotKeyRegistrationBackend: SystemHotKeyRegistrationBackend {
    var eventCallback: ((SystemHotKeyEvent) -> Void)?

    /// FourCC `Loop`, used to reject hotkey events created by another Carbon client.
    private static let signature: OSType = 0x4C6F6F70

    /// Carbon callbacks cannot capture Swift objects, so `userData` carries an unretained `self`.
    /// The backend outlives the installed handler and removes it during `stop`, making that bridge
    /// valid for the complete handler lifetime.
    private static let eventHandlerCallback: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else { return OSStatus(eventNotHandledErr) }

        let backend: CarbonSystemHotKeyRegistrationBackend = Unmanaged
            .fromOpaque(userData)
            .takeUnretainedValue()
        return backend.handle(event: event)
    }

    private var eventHandler: EventHandlerRef?

    /// Carbon requires the returned references for explicit unregistration.
    private var hotKeyReferences: [UInt32: EventHotKeyRef] = [:]

    deinit {
        // Normal ownership calls `stop` on the main thread. This is a best-effort safety net that
        // avoids invoking main-event-loop APIs if an unexpected background release occurs.
        if Thread.isMainThread {
            _ = stop()
        }
    }

    /// Installs one application-level handler shared by every registered press and release event.
    func start() -> OSStatus {
        precondition(Thread.isMainThread)
        guard eventHandler == nil else { return noErr }

        var eventTypes: [EventTypeSpec] = [
            .init(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            .init(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            )
        ]
        var installedHandler: EventHandlerRef?
        let status: OSStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandlerCallback,
            eventTypes.count,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &installedHandler
        )

        guard status == noErr, let installedHandler else {
            return status == noErr ? OSStatus(eventNotHandledErr) : status
        }

        eventHandler = installedHandler
        return noErr
    }

    /// Registers one exclusive global hotkey and retains its reference for later cleanup.
    ///
    /// Exclusive delivery matches the existing event-tap path, which consumes handled Loop
    /// shortcuts rather than forwarding them to the frontmost application.
    func register(shortcut: SystemHotKeyShortcut, id: UInt32) -> OSStatus {
        precondition(Thread.isMainThread)

        let hotKeyID: EventHotKeyID = .init(signature: Self.signature, id: id)
        var reference: EventHotKeyRef?
        let status: OSStatus = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive),
            &reference
        )

        guard status == noErr, let reference else {
            return status == noErr ? OSStatus(eventNotHandledErr) : status
        }

        hotKeyReferences[id] = reference
        return noErr
    }

    /// Unregisters every successful registration, preserving failed references for a later retry.
    func unregisterAll() -> Bool {
        precondition(Thread.isMainThread)

        // Iterate over a snapshot because successful removals mutate `hotKeyReferences`.
        let references: [UInt32: EventHotKeyRef] = hotKeyReferences
        for (id, reference): (UInt32, EventHotKeyRef) in references {
            if UnregisterEventHotKey(reference) == noErr {
                hotKeyReferences.removeValue(forKey: id)
            }
        }
        return hotKeyReferences.isEmpty
    }

    /// Removes all registrations before removing their shared Carbon event handler.
    func stop() -> Bool {
        precondition(Thread.isMainThread)
        guard unregisterAll() else { return false }
        guard let eventHandler else { return true }
        guard RemoveEventHandler(eventHandler) == noErr else { return false }

        self.eventHandler = nil
        return true
    }

    /// Validates and translates a raw Carbon event into the monitor's small typed event model.
    private func handle(event: EventRef) -> OSStatus {
        var hotKeyID: EventHotKeyID = .init(signature: 0, id: 0)
        let status: OSStatus = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr, hotKeyID.signature == Self.signature else {
            return OSStatus(eventNotHandledErr)
        }

        let phase: SystemHotKeyPhase
        switch GetEventKind(event) {
        case UInt32(kEventHotKeyPressed):
            phase = .pressed
        case UInt32(kEventHotKeyReleased):
            phase = .released
        default:
            return OSStatus(eventNotHandledErr)
        }

        eventCallback?(.init(id: hotKeyID.id, phase: phase))
        return noErr
    }
}

/// Maintains Carbon registrations and maps their numeric callbacks back to Loop actions.
///
/// Rebuilds happen on the main thread when shortcut settings change. `isRegistered` is also read
/// from `EventTapThread`, so the registered-shortcut set is protected independently from the
/// main-thread-only ID map.
@Loggable
final class SystemHotKeyMonitor {
    /// Called on the main thread after a Carbon ID has been resolved to its current binding.
    var eventCallback: ((SystemHotKeyBinding, SystemHotKeyPhase) -> Void)?

    private let backend: SystemHotKeyRegistrationBackend
    private let registeredShortcuts: OSAllocatedUnfairLock<Set<SystemHotKeyShortcut>> = .init(
        initialState: []
    )
    private var bindingsByID: [UInt32: SystemHotKeyBinding] = [:]

    /// IDs increase for the monitor's lifetime so callbacks from an older rebuild cannot resolve
    /// to an unrelated new binding. Zero is skipped because it is also the invalid/default ID.
    private var nextRegistrationID: UInt32 = 1

    /// The injectable backend keeps Carbon itself out of deterministic unit tests.
    init(backend: SystemHotKeyRegistrationBackend = CarbonSystemHotKeyRegistrationBackend()) {
        self.backend = backend
        backend.eventCallback = { [weak self] event in
            self?.handle(event: event)
        }
    }

    /// Replaces the monitor's view of configured system hotkeys.
    ///
    /// A binding is published only after Carbon accepts its registration. Rejected or unsupported
    /// shortcuts therefore remain absent from `isRegistered`, allowing the event tap to keep
    /// handling them whenever macOS delivers their events.
    func rebuild(bindings: [SystemHotKeyBinding]) -> Void {
        precondition(Thread.isMainThread)

        // Clear mappings before touching Carbon so late callbacks from the old set are ignored.
        clearBindings()
        guard backend.unregisterAll() else {
            log.error("Failed to unregister existing system hotkeys")
            return
        }
        let startStatus: OSStatus = backend.start()
        guard startStatus == noErr else {
            log.error("Failed to start system hotkey monitor: \(startStatus)")
            return
        }

        for binding: SystemHotKeyBinding in bindings {
            let id: UInt32 = nextRegistrationID
            nextRegistrationID &+= 1
            if nextRegistrationID == 0 {
                nextRegistrationID = 1
            }

            let status: OSStatus = backend.register(shortcut: binding.shortcut, id: id)
            guard status == noErr else {
                log.warn("Failed to register system hotkey \(binding.shortcut.keyCodes): \(status)")
                continue
            }

            bindingsByID[id] = binding
            _ = registeredShortcuts.withLock { $0.insert(binding.shortcut) }
        }
    }

    /// Stops Carbon delivery and clears lookup state so late callbacks cannot execute an action.
    func stop() -> Void {
        precondition(Thread.isMainThread)
        clearBindings()
        if !backend.stop() {
            log.error("Failed to stop system hotkey monitor")
        }
    }

    /// Reports whether the event-tap path should defer a chord to a successful Carbon registration.
    func isRegistered(shortcut: SystemHotKeyShortcut) -> Bool {
        registeredShortcuts.withLock { $0.contains(shortcut) }
    }

    /// Resolves only IDs from the current successful registration set.
    ///
    /// Missing IDs are intentionally ignored because Carbon may deliver a callback that was queued
    /// immediately before a rebuild removed its old binding.
    private func handle(event: SystemHotKeyEvent) -> Void {
        guard let binding: SystemHotKeyBinding = bindingsByID[event.id] else { return }
        eventCallback?(binding, event.phase)
    }

    /// Makes both callback routing and event-tap deduplication forget the current registration set.
    private func clearBindings() -> Void {
        bindingsByID.removeAll()
        registeredShortcuts.withLock { $0.removeAll() }
    }
}
